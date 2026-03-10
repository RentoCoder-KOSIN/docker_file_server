FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN go build -o fileserver .

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/fileserver .
RUN mkdir uploads && apk add --no-cache wget
EXPOSE 8080
CMD ["./fileserver"]
