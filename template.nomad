job "site" {
	region = "global"
	datacenters = ["dc1"]
	type = "service"

	group "site" {
		count = 2

		network {
			port "nginx" {
				to = 80
			}
		}

		task "nginx" {
			driver = "docker"

			config {
				image = "nginx:latest"
				ports = ["nginx"]
				volumes = ["local/site/public:/usr/share/nginx/html:ro"]
			}
			
			artifact {
				source = "https://api.minio.arsenm.dev/site/site.tar.gz"
				destination = "local/site"
			}

			service {
				name = "site"
				port = "nginx"

				tags = [
					"traefik.enable=true",

					"traefik.http.middlewares.site-redir.redirectRegex.regex=^https://arsenm\\.dev",
					"traefik.http.middlewares.site-redir.redirectRegex.replacement=https://www.arsenm.dev",
					"traefik.http.middlewares.site-redir.redirectRegex.permanent=true",
					
					"traefik.http.routers.site.rule=Host(`arsenm.dev`) || Host(`www.arsenm.dev`)",
					"traefik.http.routers.site.middlewares=site-redir",
					"traefik.http.routers.site.tls.certResolver=letsencrypt",
				]
			}
		}
	}
}
