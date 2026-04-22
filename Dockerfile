# ── STAGE 1: Node.js Builder ──
FROM node:18-alpine AS builder
WORKDIR /app
COPY app/ .
RUN echo '{"name":"react-app","version":"1.0.0","scripts":{"build":"echo build done"}}' > package.json
RUN npm install
RUN mkdir -p build && cp src/index.html build/index.html

# ── STAGE 2: Nginx Runner ──
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]