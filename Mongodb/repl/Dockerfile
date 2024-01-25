FROM mongo:5.0.24
RUN mkdir -p /config
RUN chmod 755 /config
RUN openssl rand -base64 756 > /config/mongo-keyfile
RUN chmod 400 /config/mongo-keyfile

