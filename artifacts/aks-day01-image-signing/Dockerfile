FROM nginx:alpine

# Add a custom index page
RUN echo '<h1>Supply Chain Security Lab - AKS</h1>' > /usr/share/nginx/html/index.html
RUN echo '<p>Image: myapp:v1</p>' >> /usr/share/nginx/html/index.html
RUN echo '<p>Signed with Cosign</p>' >> /usr/share/nginx/html/index.html
RUN echo '<p>Running on AKS</p>' >> /usr/share/nginx/html/index.html

EXPOSE 80
