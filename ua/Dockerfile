# Multi-stage Dockerfile for User Storefront (Flutter Web)
# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy shared models and user app source
COPY pa/shared_models /app/pa/shared_models
COPY ua/pubspec.yaml /app/ua/pubspec.yaml
COPY ua/lib /app/ua/lib
COPY ua/web /app/ua/web

WORKDIR /app/ua
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Production Nginx Server
FROM nginx:alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/ua/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
