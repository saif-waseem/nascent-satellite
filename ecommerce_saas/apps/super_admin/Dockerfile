# Multi-stage Dockerfile for Super Admin (Flutter Web)
# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy packages
COPY ecommerce_saas/packages /app/ecommerce_saas/packages
COPY ecommerce_saas/apps/super_admin/pubspec.yaml /app/ecommerce_saas/apps/super_admin/pubspec.yaml
COPY ecommerce_saas/apps/super_admin/lib /app/ecommerce_saas/apps/super_admin/lib
COPY ecommerce_saas/apps/super_admin/web /app/ecommerce_saas/apps/super_admin/web

WORKDIR /app/ecommerce_saas/apps/super_admin
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Production Nginx Server
FROM nginx:alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/ecommerce_saas/apps/super_admin/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
