## Prerequisites

- golang 1.20 or higher
- Docker
- Visual Studio Code

## Getting Started
First create a app folder
```sh
mkdir go-debugger && cd go-debugger
```
then create a simple go server and add a route with the help of chi package (`go get -u github.com/go-chi/chi/v5`).

```go
package main

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func main() {
    r := chi.NewRouter()
    r.Use(middleware.Logger)
    r.Get("/test", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Hello World!"))
    })
    http.ListenAndServe(":3573", r)
}

```

## Dockerize the app
Inorder to containerize our go app, we need to add the following content to `Dockerfile` file

```yaml
FROM golang:1.20.3-alpine3.17

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o go-debugger .

EXPOSE 3573

CMD ["/app/go-debugger"]
```
### Using Docker
1. Navigate your terminal to this directory of repository
2. Build image

```sh
docker build --file Dockerfile --tag go-debugger-image .
``` 
3. After finishing the build, we can verify it by running command below in the terminal
```sh
docker images --filter "reference=go-debugger-image"
```
4. Run your image as container
```sh
docker run -d -p 3573:3573 --name  go-debugger-container go-debugger-image
```
5. Verify if the container is successfully run with the command
```sh
docker ps --filter "name=go-debugger-container"
```
6. Check by open `http://localhost:3573/test` the page will show this to you

## Debugging the Application
Before we can debug a go application inside a docker container, we need setup the `Dockerfile` with a third-party package called delve, which will enable us to debug the Go app inside the Docker container.

1. Let’s create a dockerfile for debug only
```sh 
touch Dockerfile.debug
```
2. Add the following content to Dockerfile.debug file
```docker
FROM golang:1.20.3-alpine3.17

EXPOSE 3573 4573

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 go install -ldflags "-s -w -extldflags '-static'" github.com/go-delve/delve/cmd/dlv@latest

RUN CGO_ENABLED=0 go build -gcflags "all=-N -l" -o go-debugger .


CMD [ "/go/bin/dlv", "--listen=:4573", "--headless=true", "--log=true", "--accept-multiclient", "--api-version=2", "exec", "/app/go-debugger" ]
```
there are some commands that you must be aware of:

`--listen=:4573` this is will be the port that your debugger(delve) listen to. that’s why we expose 2 ports in `EXPOSE 3573 4573`
`CGO_ENABLED=0` is required for not making the delve configuration become dynamic compiled
`-gcflags=all="-N -l"` is used for disable inlining and optimizing because it can interfere with the debugging process
3. Next step is you must build a new image with `Dockerfile.debug` configuration
```SH
docker build --file Dockerfile.debug --tag go-debugger-image . 
```
4. After finish build the image, the next step is to remove the previous container because we can't have 2 containers with the same name
```sh
docker container rm go-debugger-container
```
5. After deleting, let's run your image as a container
```sh
docker run -d -p 3573:3573 -p 4573:4573 --name  go-debugger-container go-debugger-image
```
6. After successfully running your container. now let’s prepare the debugger in VSCode

7. After that, you will have a launch.json , Add the following content to it
```json
{
    "version": "0.2.0",
    "configurations": [{
        "name": "Go Containerized Debug",
        "type": "go",
        "request": "attach",
        "mode": "remote",
        "port": 4573,
        "host": "127.0.0.1"
    }]
}
```
8. Now, let’s try to set some breakpoints and run the debugger

9. After you run the debugger, let’s verify it with open http://localhost:3573/test . it’s should be automatic redirect to your vs code like this

## Debugging with Docker Compose
Many modern development workflows rely on container management. So to make our life easy we are going to setup our debuging env up with Docker Compose. Let's get started!

1. Make sure that no application will use ports that we expose in Dockerfile.debug. In this case, you expose ports 3573 and 4573. if there’s an application that used the port, stop it

2. let's make the docker-compose.yml with command
```sh
touch docker-compose.yml
```
3. Add the following content to your docker-compose.yml
```yaml
version: "3.9"
services:
  app:
    build: 
      context: .
      dockerfile: Dockerfile.debug
    ports:
      - "3573:3573"
      - "4573:4573"
```
4. Now, let's create and run the container with the command
```sh
docker compose up
```
5. Now let’s run the debugger in VS code like in step 8 before

6. Verify the debug with an open URL http://localhost:3573/test and it will redirect to VS code like this
