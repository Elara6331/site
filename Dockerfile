FROM alpine
RUN apk add hugo git go
RUN git clone https://gitea.arsenm.dev/Arsen6331/site.git
WORKDIR "/site"
CMD hugo server -p 80 --bind 0.0.0.0