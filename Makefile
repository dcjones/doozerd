compile: fmt
	./version.sh
	./make.sh

fmt:
	go fmt ./...

clean:
	git clean -xdf

########### local build:

LOCAL_GOPATH=${PWD}/.go_path
DOOZERD_GO_PATH=$(LOCAL_GOPATH)/src/github.com/dcjones/doozerd
DOOZER_GO_PATH=$(LOCAL_GOPATH)/src/github.com/dcjones/doozer/cmd/doozer

unexport GIT_DIR

build: fmt package bump_package_release
	echo ".git" > .pkgignore
	find . -mindepth 1 -maxdepth 1 | grep -v "\.deb" | sed 's/\.\///g' >> .pkgignore

$(LOCAL_GOPATH)/src:
	mkdir -p $(LOCAL_GOPATH)/src

$(LOCAL_GOPATH)/src/github.com/dcjones/doozer: $(LOCAL_GOPATH)/src
	GOPATH=$(LOCAL_GOPATH) go get github.com/dcjones/doozer

$(LOCAL_GOPATH)/src/github.com/bmizerany/assert: $(LOCAL_GOPATH)/src
	GOPATH=$(LOCAL_GOPATH) go get github.com/bmizerany/assert

local_build: $(LOCAL_GOPATH)/src/github.com/dcjones/doozer $(LOCAL_GOPATH)/src/github.com/bmizerany/assert
	test -e $(DOOZERD_GO_PATH) || { mkdir -p $$(dirname $(DOOZERD_GO_PATH) ); ln -sf $${PWD} $(DOOZERD_GO_PATH); }
	# instead of patching the make.sh file or tweak the go install command, we ignore errors and call 'go build' afterwards
	-GOPATH=$(LOCAL_GOPATH) go get -v .
	-GOPATH=$(LOCAL_GOPATH) ./make.sh
	 GOPATH=$(LOCAL_GOPATH) go build -o doozerd
	 GOPATH=$(LOCAL_GOPATH) go test -cpu 2 -v ./...
	 cd $(DOOZER_GO_PATH); printf 'package main\n\nconst version = `%s`\n' '$$(VERSION)' > vers.go; GOPATH=$(LOCAL_GOPATH) go build; cp doozer $(LOCAL_GOPATH)/../; cd -


########## packaging
FPM_EXECUTABLE:=$$(dirname $$(dirname $$(gem which fpm)))/bin/fpm
FPM_ARGS=-t deb -m 'Doozerd authors (see page), Daniel Bornkessel <daniel@dcjones.com> (packaging)' --url http://github.com/dcjones/doozerd -s dir
FAKEROOT=fakeroot
RELEASE=$$(cat .release 2>/dev/null || echo "0")
VERSION:=$$(GIT_DIR=$${PWD}/.git $${PWD}/version.sh | sed 's/+.*//g')

package: local_build
	rm -rf $(FAKEROOT)
	mkdir -p $(FAKEROOT)/usr/bin
	cp doozerd $(FAKEROOT)/usr/bin
	cp doozer $(FAKEROOT)/usr/bin
	rm -rf *.deb

	$(FPM_EXECUTABLE) -n "doozerd" \
		-C $(FAKEROOT) \
		--description "doozerd" \
		$(FPM_ARGS) -t deb -v $(VERSION) --iteration $(RELEASE) .;


bump_package_release:
		echo $$(( $(RELEASE) + 1 )) > .release
