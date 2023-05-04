job "site" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "site" {
    count = 2

    network {
      port "nginx" {
        to = 80
      }
    }

    task "nginx" {
      driver = "docker"

      env {
        // Hack to force Nomad to re-deploy the service
        // instead of ignoring it
        COMMIT_SHA = "${DRONE_COMMIT_SHA}"
      }

      config {
        image   = "nginx:latest"
        ports   = ["nginx"]
        volumes = ["local/site/public:/usr/share/nginx/html:ro"]
      }

      artifact {
        source      = "https://api.minio.elara.ws/site/site.tar.gz"
        destination = "local/site"
      }

      service {
        name = "site"
        port = "nginx"

        tags = [
          "traefik.enable=true",

          "traefik.http.middlewares.site-redir.redirectRegex.regex=^https://elara\\.ws",
          "traefik.http.middlewares.site-redir.redirectRegex.replacement=https://www.elara.ws",
          "traefik.http.middlewares.site-redir.redirectRegex.permanent=true",

          "traefik.http.routers.site.rule=Host(`elara.ws`) || Host(`www.elara.ws`)",
          "traefik.http.routers.site.middlewares=site-redir",
          "traefik.http.routers.site.tls.certResolver=letsencrypt",
        ]
      }
    }
  }
}
