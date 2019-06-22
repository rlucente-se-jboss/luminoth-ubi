FROM registry.redhat.io/ubi7/python-36

RUN    pip install luminoth[tf] \
    && /opt/app-root/bin/lumi checkpoint refresh \
    && /opt/app-root/bin/lumi checkpoint download fast

ENTRYPOINT ["/opt/app-root/bin/lumi", "server", "web", "--host", "0.0.0.0", "--port", "5000", "--debug", "--checkpoint", "fast"]
EXPOSE 5000
USER 1000

