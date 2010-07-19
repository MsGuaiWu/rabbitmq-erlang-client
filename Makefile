#   The contents of this file are subject to the Mozilla Public License
#   Version 1.1 (the "License"); you may not use this file except in
#   compliance with the License. You may obtain a copy of the License at
#   http://www.mozilla.org/MPL/
#
#   Software distributed under the License is distributed on an "AS IS"
#   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
#   License for the specific language governing rights and limitations
#   under the License.
#
#   The Original Code is the RabbitMQ Erlang Client.
#
#   The Initial Developers of the Original Code are LShift Ltd.,
#   Cohesive Financial Technologies LLC., and Rabbit Technologies Ltd.
#
#   Portions created by LShift Ltd., Cohesive Financial
#   Technologies LLC., and Rabbit Technologies Ltd. are Copyright (C) 
#   2007 LShift Ltd., Cohesive Financial Technologies LLC., and Rabbit 
#   Technologies Ltd.; 
#
#   All Rights Reserved.
#
#   Contributor(s): Ben Hood <0x6e6562@gmail.com>.
#

DEPS=$(shell erl -noshell -eval '{ok,[{_,_,[_,_,{modules, Mods},_,_,_]}]} = \
                                 file:consult("rabbit_common.app"), \
                                 [io:format("~p ",[M]) || M <- Mods], halt().')

VERSION=0.0.0
SOURCE_PACKAGE_DIR=$(PACKAGE)-$(VERSION)-src
SOURCE_PACKAGE_TAR_GZ=$(SOURCE_PACKAGE_DIR).tar.gz

BROKER_HEADERS=$(wildcard $(BROKER_DIR)/$(INCLUDE_DIR)/*.hrl)
BROKER_SOURCES=$(wildcard $(BROKER_DIR)/$(SOURCE_DIR)/*.erl)
BROKER_DEPS=$(BROKER_HEADERS) $(BROKER_SOURCES)

include common.mk

run_in_broker: compile $(BROKER_DEPS) $(EBIN_DIR)/$(PACKAGE).app
	$(MAKE) RABBITMQ_SERVER_START_ARGS='$(PA_LOAD_PATH)' -C $(BROKER_DIR) run

clean: common_clean
	rm -f $(INTARGETS)
	rm -rf $(DIST_DIR)

%.app: %.app.in
	sed -e 's:%%VSN%%:$(VERSION):g' < $< > $@

doc: $(DOC_DIR)/index.html

$(DOC_DIR)/overview.edoc: $(SOURCE_DIR)/overview.edoc.in
	mkdir -p $(DOC_DIR)
	sed -e 's:%%VERSION%%:$(VERSION):g' < $< > $@

$(DOC_DIR)/index.html: $(DEPS_DIR)/$(COMMON_PACKAGE_DIR) $(DOC_DIR)/overview.edoc $(SOURCES)
	$(LIBS_PATH) erl -noshell -eval 'edoc:application(amqp_client, ".", [{preprocess, true}])' -run init stop

###############################################################################
##  Testing
###############################################################################

include test.mk

test_common_package: common_package package prepare_tests
	$(MAKE) start_test_broker_node
	OK=true && \
	TMPFILE=$(MKTEMP) && \
	    { $(LIBS_PATH) erl -noshell -pa $(TEST_DIR) \
	    -eval 'error_logger:tty(false), network_client_SUITE:test(), halt().' 2>&1 | \
		tee $$TMPFILE || OK=false; } && \
	{ egrep "All .+ tests (successful|passed)." $$TMPFILE || OK=false; } && \
	rm $$TMPFILE && \
	$(MAKE) stop_test_broker_node && \
	$$OK

compile_tests: $(TEST_DIR) $(EBIN_DIR)/$(PACKAGE).app

$(TEST_DIR)/%.beam: $(TEST_DIR)

.PHONY: $(TEST_DIR)
$(TEST_DIR): $(DEPS_DIR)/$(COMMON_PACKAGE_DIR)
	$(MAKE) -C $(TEST_DIR)

###############################################################################
##  Packaging
###############################################################################

COPY=cp -pR

common_package: $(DIST_DIR)/$(COMMON_PACKAGE_EZ)

$(DIST_DIR)/$(COMMON_PACKAGE_EZ): $(DIST_DIR)/$(COMMON_PACKAGE_DIR) | $(DIST_DIR)
	(cd $(DIST_DIR); zip -r $(COMMON_PACKAGE_EZ) $(COMMON_PACKAGE_DIR))

$(DIST_DIR)/$(COMMON_PACKAGE_DIR): $(BROKER_DEPS) $(COMMON_PACKAGE_DIR).app | $(DIST_DIR)
	$(MAKE) -C $(BROKER_DIR)
	rm -rf $(DIST_DIR)/$(COMMON_PACKAGE_DIR)
	mkdir -p $(DIST_DIR)/$(COMMON_PACKAGE_DIR)/$(INCLUDE_DIR)
	mkdir -p $(DIST_DIR)/$(COMMON_PACKAGE_DIR)/$(EBIN_DIR)
	cp $(COMMON_PACKAGE_DIR).app $(DIST_DIR)/$(COMMON_PACKAGE_DIR)/$(EBIN_DIR)/
	$(foreach DEP, $(DEPS), \
	    ( cp $(BROKER_DIR)/ebin/$(DEP).beam $(DIST_DIR)/$(COMMON_PACKAGE_DIR)/$(EBIN_DIR)/ \
	    );)
	cp $(BROKER_DIR)/include/*.hrl $(DIST_DIR)/$(COMMON_PACKAGE_DIR)/$(INCLUDE_DIR)/

source_tarball: clean $(DIST_DIR)/$(COMMON_PACKAGE_EZ) | $(DIST_DIR)
	mkdir -p $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(DIST_DIR)
	$(COPY) $(DIST_DIR)/$(COMMON_PACKAGE_EZ) $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(DIST_DIR)/
	$(COPY) README $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/
	$(COPY) common.mk $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/
	$(COPY) Makefile.in $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/Makefile
	mkdir -p $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(SOURCE_DIR)
	$(COPY) $(SOURCE_DIR)/*.erl $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(SOURCE_DIR)/
	mkdir -p $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(EBIN_DIR)
	$(COPY) $(EBIN_DIR)/*.app $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(EBIN_DIR)/
	mkdir -p $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(INCLUDE_DIR)
	$(COPY) $(INCLUDE_DIR)/*.hrl $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(INCLUDE_DIR)/
	mkdir -p $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(TEST_DIR)
	$(COPY) $(TEST_DIR)/*.erl $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(TEST_DIR)/
	$(COPY) $(TEST_DIR)/Makefile $(DIST_DIR)/$(SOURCE_PACKAGE_DIR)/$(TEST_DIR)/
	cd $(DIST_DIR) ; tar cvzf $(SOURCE_PACKAGE_TAR_GZ) $(SOURCE_PACKAGE_DIR)

$(DIST_DIR):
	mkdir -p $@
