FROM nginx:alpine

# Install certbot for Let's Encrypt
RUN apk add --no-cache certbot certbot-nginx

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create certbot webroot
RUN mkdir -p /var/www/certbot

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
