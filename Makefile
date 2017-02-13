## Configuration #####################################################

DOMAIN         ?= emacsmirror.net
PUBLIC         ?= https://$(DOMAIN)
PUBLISH_BUCKET ?= s3://$(DOMAIN)
PREVIEW_BUCKET ?= s3://preview.$(DOMAIN)
S3_ZONE        ?= s3-website.eu-central-1
PUBLISH_S3_URL ?= http://$(DOMAIN).$(S3_ZONE).amazonaws.com
PREVIEW_S3_URL ?= http://preview.$(DOMAIN).$(S3_ZONE).amazonaws.com

EMACS           ?= emacs
SITE_LISP       ?= ~/.emacs.d/lib/
EPKG_REPOSITORY ?= ~/Repos/emacsmirror/
CUSTOM_FILE     ?= ~/.emacs.d/custom.el

SRC   = .
DST   = /stats
SYNC  = --exclude "*"
SYNC += --include "*.html"
SYNC += --exclude "index.html"

BABEL  = compare.org
BABEL += emacsorphanage.org
BABEL += kludges.org
BABEL += issues.org
BABEL += melpa-missing.org

HTML   = config.html
HTML  += compare.html
HTML  += emacsorphanage.html
HTML  += kludges.html
HTML  += issues.html
HTML  += melpa-missing.html

DEPS   = borg
DEPS  += closql
DEPS  += dash
DEPS  += elx
DEPS  += emir
DEPS  += epkg
DEPS  += emacsql
DEPS  += finalize
DEPS  += ghub
DEPS  += magit/lisp
DEPS  += melpa-db
DEPS  += org/lisp
DEPS  += packed
DEPS  += request
DEPS  += with-editor

LOAD_PATH = $(addprefix -L $(SITE_LISP),$(DEPS))
BATCH     = $(EMACS) -Q --batch $(LOAD_PATH)

## Usage #############################################################

help:
	$(info )
	$(info make babel        - evaluate code-blocks)
	$(info make html         - generate html)
	$(info make preview      - preview html)
	$(info make publish      - publish html)
	$(info make clean        - remove html)
	$(info )
	$(info Public:  $(PUBLIC))
	$(info Preview: $(PREVIEW_S3_URL))
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
	-e "Code block returned no value."


%.html: force
	@echo "Generating $@..."
	@$(BATCH) $(subst html,org,$@) --eval "(progn\
	(require 'org)\
	(let ((org-babel-confirm-evaluate-answer-no 'noeval))\
	  (org-html-export-to-html)))" 2>&1 |\
	grep "Evaluation of this emacs-lisp code block"
	@rm -f $@~

preview:
	@echo "Uploading to $(PREVIEW_BUCKET)..."
	@aws s3 sync $(SRC) $(PREVIEW_BUCKET)$(DST) --delete $(SYNC)

publish:
	@echo "Uploading to $(PUBLISH_BUCKET)..."
	@aws s3 sync $(SRC) $(PUBLISH_BUCKET)$(DST) --delete $(SYNC)

clean:
	@echo "Cleaning..."
	@rm -rf $(HTML) $(addsuffix ~,$(HTML))
