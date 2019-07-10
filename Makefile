## Configuration #####################################################

DOMAIN         ?= emacsmirror.net
PUBLIC         ?= https://$(DOMAIN)
CFRONT_DIST    ?= E1IXJGPIOM4EUW
PUBLISH_BUCKET ?= s3://$(DOMAIN)
S3_ZONE        ?= s3-website.eu-central-1
PUBLISH_S3_URL ?= http://$(DOMAIN).$(S3_ZONE).amazonaws.com

EMACS           ?= emacs
SITE_LISP       ?= ~/.emacs.d/lib/
EPKG_REPOSITORY ?= ~/git/emacs/epkgs/
CUSTOM_FILE     ?= ~/.emacs.d/custom.el

SRC   = .
DST   = /stats
SYNC  = --exclude "*"
SYNC += --include "*.html"
SYNC += --exclude "index.html"

HTML   = compare.html
HTML  += emacsorphanage.html
HTML  += emacswiki.html
HTML  += issues.html
HTML  += kludges.html
HTML  += licenses.html
HTML  += melpa.html

BABEL  = $(HTML:.html=.org)

DEPS   = borg
DEPS  += closql
DEPS  += dash
DEPS  += elx
DEPS  += emir
DEPS  += epkg
DEPS  += emacsql
DEPS  += finalize
DEPS  += ghub
DEPS  += graphql
DEPS  += hydra
DEPS  += magit/lisp
DEPS  += magit-popup
DEPS  += melpa-db
DEPS  += org/lisp
DEPS  += packed
DEPS  += request
DEPS  += transient/lisp
DEPS  += treepy
DEPS  += with-editor

LOAD_PATH = $(addprefix -L $(SITE_LISP),$(DEPS))
BATCH     = $(EMACS) -Q --batch $(LOAD_PATH)

## Usage #############################################################

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

## Targets ###########################################################

babel: $(BABEL)
html:  $(HTML)
force:

%.org: force
	@echo "Updating $@..."
	@$(BATCH) $@ --eval "(progn\
	(load \"$(CUSTOM_FILE)\")\
	(require 'org)\
	(let ((epkg-repository \"$(EPKG_REPOSITORY)\")\
	      (org-confirm-babel-evaluate nil))\
	  (org-babel-execute-buffer))\
	(save-buffer))" 2>&1 | grep -v \
	-e "((" \
	-e "Code block evaluation complete." \
	-e "Code block returned no value." \
	-e "custom.el (source)..."
	@echo

%.html: %.org
	@echo "Generating $@..."
	@$(BATCH) $(subst html,org,$@) --eval "(progn\
	(require 'org)\
	(let ((org-babel-confirm-evaluate-answer-no 'noeval))\
	  (org-html-export-to-html)))" 2>&1 |\
	grep -v "Evaluation of this emacs-lisp code block" | true
	@rm -f $@~

publish: html
	@echo "Uploading to $(PUBLISH_BUCKET)..."
	@aws s3 sync $(SRC) $(PUBLISH_BUCKET)$(DST) --delete $(SYNC)
	@aws cloudfront create-invalidation \
	--distribution-id $(CFRONT_DIST) --paths "/stats/*" > /dev/null

clean:
	@echo "Cleaning..."
	@rm -rf $(HTML) $(addsuffix ~,$(HTML))
