FROM alpine:3.20
ARG VERSION=dev
LABEL org.opencontainers.image.title="containerdesktop-compat-demo"
RUN printf '%s\n' "$VERSION" > /version.txt
CMD ["sh", "-c", "cat /version.txt && sleep 3600"]
