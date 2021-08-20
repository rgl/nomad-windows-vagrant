# escape=`
FROM golang:1.17.0 AS builder
WORKDIR /Users/ContainerUser/go-info
COPY go.* ./
RUN go mod download
COPY *.go ./
RUN go build

FROM mcr.microsoft.com/windows/nanoserver:1809
WORKDIR /app
COPY --from=builder /Users/ContainerUser/go-info/go-info.exe ./
EXPOSE 8000/tcp
# run as ContainerAdministrator because nomad directories (/alloc, /local,
# /secrets) are not accessible by the ContainerUser account.
# TODO see how to access the nomad directories as ContainerUser.
USER ContainerAdministrator
ENTRYPOINT ["/app/go-info.exe"]
