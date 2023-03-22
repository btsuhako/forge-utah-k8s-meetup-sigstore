FROM golang:1.19-bullseye as build

WORKDIR /go/src/app

COPY go.mod go.sum ./
RUN go mod download

COPY src/*.go ./

RUN go build -o /go/bin/app .

FROM gcr.io/distroless/base-debian11
COPY --from=build /go/bin/app /

EXPOSE "8080"

CMD [ "/app" ]
