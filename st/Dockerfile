# Multi-stage Dockerfile for Store Admin (Flutter Web)
# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy shared models and dependencies
COPY pa/shared_models /app/pa/shared_models
COPY st/pubspec.yaml /app/st/pubspec.yaml
COPY st/lib /app/st/lib
COPY st/web /app/st/web

WORKDIR /app/st
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Production Nginx Server
FROM nginx:alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/st/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
