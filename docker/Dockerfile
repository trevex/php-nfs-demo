# Source: https://github.com/docker-library/php/blob/23fa543b368fc990039bde030d802fc4f5768049/8.0/bullseye/apache/Dockerfile
FROM php:8.0-apache

# Install everything we need for NFS and our entrypoint
RUN apt-get update -y && apt-get install -y \
    tini \
    nfs-common \
    nfs-kernel-server \
    && apt-get clean

COPY run.sh /run.sh
RUN chmod +x /run.sh

COPY index.php /var/www/html

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]
