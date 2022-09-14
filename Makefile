all: public docker

public:
	hugo

docker:
	docker build -t arsen6331/site .

.PHONY: docker