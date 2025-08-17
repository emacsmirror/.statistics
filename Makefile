## Configuration

DOMAIN         ?= emacsmirror.net
PUBLIC         ?= https://$(DOMAIN)
CFRONT_DIST    ?= E1IXJGPIOM4EUW
PUBLISH_BUCKET ?= s3://$(DOMAIN)
S3_ZONE        ?= s3-website.eu-central-1
PUBLISH_S3_URL ?= http://$(DOMAIN).$(S3_ZONE).amazonaws.com

EMACS           ?= emacs
SITE_LISP       ?= ~/.config/emacs/lib/
EPKG_REPOSITORY ?= ~/src/emacs/epkgs/

SRC   = .
DST   = /stats
SYNC  = --exclude "*"
SYNC += --include "*.html"
SYNC += --exclude "index.html"
SYNC += --exclude "borg/*"
SYNC += --exclude "epkg/*"

BABEL = $(filter-out config.org misc.org, $(wildcard *.org))
HTML  = $(BABEL:.org=.html)

DEPS   = borg
DEPS  += closql
DEPS  += compat
DEPS  += cond-let
DEPS  += dash
DEPS  += elx
DEPS  += emir
DEPS  += epkg/lisp
DEPS  += emacsql
DEPS  += f
DEPS  += ghub/lisp
DEPS  += graphql
DEPS  += llama
DEPS  += magit/lisp
DEPS  += org/lisp
DEPS  += package-build
DEPS  += packed
DEPS  += s
DEPS  += transient/lisp
DEPS  += treepy
DEPS  += with-editor/lisp

LOAD_PATH ?= $(addprefix -L $(SITE_LISP),$(DEPS))
BATCH      = $(EMACS) -Q --batch $(LOAD_PATH)

## Usage

help:
	$(info )
	$(info make babel        - evaluate code-blocks)
	$(info make html         - generate html)
	$(info make publish      - publish html)
	$(info make clean        - remove html)
	$(info )
	$(info Public:  $(PUBLIC))
	$(info Publish: $(PUBLISH_S3_URL))
	@echo

## Targets

babel: $(BABEL)
html:  $(HTML)
force:

%.org: force
	@echo "Updating $@..."
	@$(BATCH) $@ --eval "(progn\
	(require 'org)\
	(setq epkg-repository \"$(EPKG_REPOSITORY)\")\
	(setq org-confirm-babel-evaluate nil)\
	(org-fold-show-all)\
	(org-babel-execute-buffer)\
	(save-buffer))" 2>&1 | (grep -v -e "((" || true)

%.html: force
	@echo "Generating $@..."
	@$(BATCH) $(subst html,org,$@) --eval "(progn\
	(require 'org)\
	(defun org-babel-check-evaluate (_) nil)\
	(org-html-export-to-html))"
	@rm -f $@~

publish:
	@echo "Uploading to $(PUBLISH_BUCKET)..."
	@aws s3 sync $(SRC) $(PUBLISH_BUCKET)$(DST) --delete $(SYNC)
	@echo "Performing CDN invalidation"
	@aws cloudfront create-invalidation \
	--distribution-id $(CFRONT_DIST) --paths "/stats/*" > /dev/null

clean:
	@echo "Cleaning..."
	@rm -rf $(HTML) $(addsuffix ~,$(HTML))
