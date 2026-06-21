.PHONY: all check munge full-ttf status dist src-dist full-dist norm check-harder pre-patch clean

# Release version
VERSION = 2.37
# Snapshot version
SNAPSHOT =
# Initial source directory, assumed read-only
SRCDIR  = src
# Directory where temporary files live
TMPDIR  = tmp
# Directory where final files are created
BUILDDIR  = build
# Directory where final archives are created
DISTDIR = dist

# Release layout
FONTCONFDIR = fontconfig
DOCDIR = .
SCRIPTSDIR = scripts
TTFDIR = ttf

ifeq "$(SNAPSHOT)" ""
ARCHIVEVER = $(VERSION)
else
ARCHIVEVER = $(VERSION)-$(SNAPSHOT)
endif

SRCARCHIVE  = dejavu-fonts-$(ARCHIVEVER)
FULLARCHIVE = dejavu-fonts-ttf-$(ARCHIVEVER)

ARCHIVEEXT = .zip .tar.bz2
SUMEXT     = .zip.md5 .tar.bz2.md5 .tar.bz2.sha512

OLDSTATUS   = $(DOCDIR)/status.txt

GENERATE    = $(SCRIPTSDIR)/generate.pe
TTPOSTPROC  = $(SCRIPTSDIR)/ttpostproc.pl
LGC         = $(SCRIPTSDIR)/lgc.pe
UNICOVER    = $(SCRIPTSDIR)/unicover.pl
LANGCOVER   = $(SCRIPTSDIR)/langcover.pl
STATUS      = $(SCRIPTSDIR)/status.pl
PROBLEMS    = $(SCRIPTSDIR)/problems.pl
NORMALIZE   = $(SCRIPTSDIR)/sfdnormalize.pl

SRC      := $(wildcard $(SRCDIR)/*.sfd)
SFDFILES := $(patsubst $(SRCDIR)/%, %, $(SRC))
FULLSFD  := $(patsubst $(SRCDIR)/%.sfd, $(TMPDIR)/%.sfd, $(SRC))
NORMSFD  := $(patsubst %, %.norm, $(FULLSFD))
FULLTTF  := $(patsubst $(TMPDIR)/%.sfd, $(BUILDDIR)/%.ttf, $(FULLSFD))

FONTCONF     := $(wildcard $(FONTCONFDIR)/*.conf)
# lgc confs are excluded from the full archive; the wildcard drives that filter.
FONTCONFLGC  := $(wildcard $(FONTCONFDIR)/*lgc*.conf)
FONTCONFFULL := $(filter-out $(FONTCONFLGC), $(FONTCONF))

STATICDOC := $(addprefix $(DOCDIR)/, AUTHORS LICENSE NEWS README.md)
STATICSRCDOC := $(addprefix $(DOCDIR)/, BUILDING.md)

all : full-ttf

$(TMPDIR)/%.sfd: $(SRCDIR)/%.sfd
	@echo "[1] $< => $@"
	install -d $(dir $@)
	sed "s@\(Version:\? \)\(0\.[0-9]\+\.[0-9]\+\|[1-9][0-9]*\.[0-9]\+\)@\1$(VERSION)@" $< > $@
	touch -r $< $@

$(BUILDDIR)/%.ttf: $(TMPDIR)/%.sfd
	@echo "[3] $< => $@"
	install -d $(dir $@)
	$(GENERATE) $<
	mv $<.ttf $@
	$(TTPOSTPROC) $@
	$(RM) $@~
	touch -r $< $@

$(BUILDDIR)/status.txt: $(FULLSFD)
	@echo "[4] => $@"
	install -d $(dir $@)
	$(STATUS) $(VERSION) $(OLDSTATUS) $(FULLSFD) > $@

$(BUILDDIR)/Makefile: Makefile
	@echo "[7] => $@"
	install -d $(dir $@)
	sed -e "s+^VERSION\([[:space:]]*\)=\(.*\)+VERSION = $(VERSION)+g"\
	    -e "s+^SNAPSHOT\([[:space:]]*\)=\(.*\)+SNAPSHOT = $(SNAPSHOT)+g" < $< > $@
	touch -r $< $@

$(TMPDIR)/$(SRCARCHIVE): $(BUILDDIR)/status.txt $(BUILDDIR)/Makefile $(FULLSFD)
	@echo "[8] => $@"
	install -d -m 0755 $@/$(SCRIPTSDIR)
	install -d -m 0755 $@/$(SRCDIR)
	install -d -m 0755 $@/$(FONTCONFDIR)
	install -d -m 0755 $@/$(DOCDIR)
	install -p -m 0644 $(BUILDDIR)/Makefile $@
	install -p -m 0755 $(GENERATE) $(TTPOSTPROC) $(LGC) $(NORMALIZE) \
	                   $(UNICOVER) $(LANGCOVER) $(STATUS) $(PROBLEMS) \
	                   $@/$(SCRIPTSDIR)
	install -p -m 0644 $(FULLSFD) $@/$(SRCDIR)
	install -p -m 0644 $(FONTCONF) $@/$(FONTCONFDIR)
	install -p -m 0644 $(BUILDDIR)/status.txt \
	                   $(STATICDOC) $(STATICSRCDOC) $@/$(DOCDIR)

$(TMPDIR)/$(FULLARCHIVE): full-ttf $(BUILDDIR)/status.txt
	@echo "[8] => $@"
	install -d -m 0755 $@/$(TTFDIR)
	install -d -m 0755 $@/$(FONTCONFDIR)
	install -d -m 0755 $@/$(DOCDIR)
	install -p -m 0644 $(FULLTTF) $@/$(TTFDIR)
	install -p -m 0644 $(FONTCONFFULL) $@/$(FONTCONFDIR)
	install -p -m 0644 $(BUILDDIR)/status.txt $(STATICDOC) $@/$(DOCDIR)

$(DISTDIR)/%.zip: $(TMPDIR)/%
	@echo "[9] => $@"
	install -d $(dir $@)
	(cd $(TMPDIR); zip -rv $(abspath $@) $(notdir $<))

$(DISTDIR)/%.tar.bz2: $(TMPDIR)/%
	@echo "[9] => $@"
	install -d $(dir $@)
	(cd $(TMPDIR); tar cjvf $(abspath $@) $(notdir $<))

%.md5: %
	@echo "[10] => $@"
	(cd $(dir $<); md5sum -b $(notdir $<) > $(abspath $@))

%.sha512: %
	@echo "[10] => $@"
	(cd $(dir $<); sha512sum -b $(notdir $<) > $(abspath $@))

%.sfd.norm: %.sfd
	@echo "[11] $< => $@"
	$(NORMALIZE) $<
	touch -r $< $@

check : $(NORMSFD)
	for sfd in $^ ; do \
	echo "[12] Checking $$sfd" ;\
	$(PROBLEMS)  $$sfd ;\
	done

munge: $(NORMSFD)
	for sfd in $(SFDFILES) ; do \
	echo "[13] $(TMPDIR)/$$sfd.norm => $(SRCDIR)/$$sfd" ;\
	cp $(TMPDIR)/$$sfd.norm $(SRCDIR)/$$sfd ;\
	done

full-ttf : $(FULLTTF)

status : $(BUILDDIR)/status.txt

dist : src-dist full-dist

src-dist :  $(addprefix $(DISTDIR)/$(SRCARCHIVE),  $(ARCHIVEEXT) $(SUMEXT))

full-dist : $(addprefix $(DISTDIR)/$(FULLARCHIVE), $(ARCHIVEEXT) $(SUMEXT))

norm : $(NORMSFD)

check-harder : clean check

pre-patch : munge clean

clean :
	$(RM) -r $(TMPDIR) $(BUILDDIR) $(DISTDIR)
