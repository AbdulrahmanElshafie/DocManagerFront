FROM nginx:alpine

WORKDIR /usr/share/nginx/html

# Remove default nginx files
RUN rm -rf ./*

# Copy app files
COPY . .

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
