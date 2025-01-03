FROM golang:1.23 AS build

WORKDIR /go/src/app
COPY go.mod go.sum /go/src/app/
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags "-s -w" -o /go/bin/k8s-admission cmd/main.go

FROM gcr.io/distroless/static-debian12
COPY --from=build /go/bin/k8s-admission /
CMD ["/k8s-admission"]
