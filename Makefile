.PHONY: all
all: build-tests

.PHONY: build-tests
build-tests:
	@mkdir -p out
	@odin build tests -out:out/testrunner -build-mode:test

.PHONY: build-tsan
build-tsan:
	@mkdir -p out
	@odin build tests -out:out/testrunner -build-mode:test -sanitize:thread

.PHONY: test
test:
	@mkdir -p out
	@odin test tests -out:out/testrunner

.PHONY: tsan
tsan:
	@mkdir -p out
	@odin test tests -out:out/testrunner -sanitize:thread

.PHONY: clean
clean:
	@rm -r out
