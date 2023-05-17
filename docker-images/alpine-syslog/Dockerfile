FROM alpine:3.18.0

USER root

# Install python/pip
ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools

COPY syslog_gen.py /usr/sbin/syslog_gen.py
RUN chmod +x /usr/sbin/syslog_gen.py
COPY dataset.txt /usr/sbin/dataset.txt

# Create a group and user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Tell docker that all future commands should run as the appuser user
USER appuser