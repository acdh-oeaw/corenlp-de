FROM alpine:3.21 AS builder

RUN apk add --no-cache py3-pip wget unzip

WORKDIR /opt

# Keep the existing CoreNLP and German model download procedure.
RUN pip install grepurl --break-system-packages && \
    wget --no-check-certificate $(grepurl -r 'stanford-corenlp-.*\.zip' -a http://stanfordnlp.github.io/CoreNLP) && \
    unzip stanford-corenlp-*.zip && \
    mv $(ls -d stanford-corenlp-*/) corenlp && rm *.zip

WORKDIR /opt/corenlp
RUN wget --no-check-certificate $(grepurl -r 'german.*jar$' -a http://stanfordnlp.github.io/CoreNLP | head -n 1)

# Java 17 replaces Java 8, which cannot load the current CoreNLP classes.
FROM eclipse-temurin:17-jre-alpine-3.21

RUN apk add --no-cache py3-pip && \
    pip install pytest pexpect requests --break-system-packages

WORKDIR /opt/corenlp
COPY --from=builder /opt/corenlp .
COPY test_api.py .

ENV JAVA_XMX=4g \
    ANNOTATORS=tokenize,ssplit,pos,lemma,ner,depparse,coref,natlog,openie,parse \
    TIMEOUT_MILLISECONDS=600000 \
    PORT=9000

EXPOSE 9000

CMD ["sh", "-c", "exec java -Xmx\"$JAVA_XMX\" -cp '*' edu.stanford.nlp.pipeline.StanfordCoreNLPServer -annotators \"$ANNOTATORS\" -port \"$PORT\" -timeout \"$TIMEOUT_MILLISECONDS\""]
