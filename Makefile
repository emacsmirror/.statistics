## Configuration

SITE_LISP       ?= ~/.config/emacs/lib/
EPKG_REPOSITORY ?= ~/src/emacs/epkgs/

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

EMACS       ?= emacs
EMACS_ARGS  ?=
EMACS_Q_ARG ?= -Q
EMACS_BATCH ?= $(EMACS) $(EMACS_Q_ARG) --batch $(EMACS_ARGS) $(LOAD_PATH)

DOMAIN      ?= stats.emacsmirror.org
TARGET       = $(subst .,_,$(DOMAIN)):mirror

RCLONE      ?= rclone
RCLONE_ARGS ?= -v

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
	@$(EMACS_BATCH) $@ --eval "(progn\
	(require 'org)\
	(setq epkg-repository \"$(EPKG_REPOSITORY)\")\
	(setq org-confirm-babel-evaluate nil)\
	(org-fold-show-all)\
	(org-babel-execute-buffer)\
	(save-buffer))" 2>&1 | (grep -v -e "((" || true)

%.html: force
	@echo "Generating $@..."
	@$(EMACS_BATCH) $(subst html,org,$@) --eval "(progn\
	(require 'org)\
	(defun org-babel-check-evaluate (_) nil)\
	(org-html-export-to-html))"
	@rm -f $@~

publish:
	@echo "Publishing to $(DOMAIN)..."
	$(RCLONE) sync --include "*.html" $(RCLONE_ARGS) . $(TARGET)

clean:
	@echo "Cleaning..."
	@rm -rf $(HTML) $(addsuffix ~,$(HTML))
