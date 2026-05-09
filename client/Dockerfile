FROM ghcr.io/cirruslabs/flutter AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .

ARG AUTH0_DOMAIN
ARG AUTH0_CLIENT_ID
ARG AUTH0_AUDIENCE
ARG API_URL

RUN flutter build web --release \
    --no-wasm-dry-run \
    --dart-define=AUTH0_DOMAIN=${AUTH0_DOMAIN} \
    --dart-define=AUTH0_CLIENT_ID=${AUTH0_CLIENT_ID} \
    --dart-define=AUTH0_AUDIENCE=${AUTH0_AUDIENCE} \
    --dart-define=API_URL=${API_URL}

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
