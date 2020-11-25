# escape=`
FROM golang:1.15.4 AS builder
WORKDIR /Users/ContainerUser/go/src/info
COPY *.go ./
RUN go build

FROM mcr.microsoft.com/windows/nanoserver:1809
WORKDIR /app
COPY --from=builder /Users/ContainerUser/go/src/info/info.exe ./
EXPOSE 8000
ENTRYPOINT ["/app/info.exe"]
