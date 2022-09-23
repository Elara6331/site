all: public docker

site:
	hugo

docker: site
	docker buildx build --platform linux/amd64 --tag arsen6331/site:amd64 . 
	docker buildx build --platform linux/arm64/v8 --tag arsen6331/site:arm64 .
	docker push arsen6331/site -a
	docker manifest create arsen6331/site:latest --amend arsen6331/site:arm64 --amend arsen6331/site:amd64
	docker manifest push arsen6331/site:latest

.PHONY: docker site