FROM golang:1.20.3-alpine3.17 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o go-debugger .

EXPOSE 3573

CMD ["/app/go-debugger"]
