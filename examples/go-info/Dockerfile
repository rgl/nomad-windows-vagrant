# escape=`
FROM golang:1.15.6 AS builder
WORKDIR /Users/ContainerUser/go/src/info
COPY *.go ./
RUN go build

FROM mcr.microsoft.com/windows/nanoserver:1809
WORKDIR /app
COPY --from=builder /Users/ContainerUser/go/src/info/info.exe ./
EXPOSE 8000/tcp
# run as ContainerAdministrator because nomad directories (/alloc, /local,
# /secrets) are not accessible by the ContainerUser account.
# TODO see how to access the nomad directories as ContainerUser.
USER ContainerAdministrator
ENTRYPOINT ["/app/go-info.exe"]
