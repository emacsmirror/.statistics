EMACS           ?= emacs
SITE_LISP       ?= ~/.emacs.d/lib/
EPKG_REPOSITORY ?= ~/Repos/emacsmirror/
CUSTOM_FILE     ?= ~/.emacs.d/custom.el

BABEL  = compare.org
BABEL += issues.org
BABEL += melpa-missing.org

HTML   = config.html
HTML  += compare.html
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

html:  $(HTML)
babel: $(BABEL)
force:

help:
	$(info make babel        - evaluate code-blocks)
	$(info make [html]       - generate html)
	$(info make publish      - publish html)
	$(info make clean        - remove html)

%.org: force
	@printf ">>> Updating $@\n"
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
	@printf ">>> Generating $@\n"
	@$(BATCH) $(subst html,org,$@) --eval "(progn\
	(require 'org)\
	(let ((org-babel-confirm-evaluate-answer-no 'noeval))\
	  (org-html-export-to-html)))" 2>&1 |\
	grep "Evaluation of this emacs-lisp code-block"
	@rm -f $@~

publish:
	@aws s3 sync . s3://emacsmirror.net/stats/ --delete \
	--exclude "*" --include "*.html" --exclude "index.html"

clean:
	@rm -rf $(HTML) $(addsuffix ~,$(HTML))
