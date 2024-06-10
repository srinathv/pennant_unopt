BUILDDIR := build
PRODUCT := pennant

SRCDIR := src

HDRS := $(wildcard $(SRCDIR)/*.hh)
SRCS := $(wildcard $(SRCDIR)/*.cc)
OBJS := $(SRCS:$(SRCDIR)/%.cc=$(BUILDDIR)/%.o)
DEPS := $(SRCS:$(SRCDIR)/%.cc=$(BUILDDIR)/%.d)

BINARY := $(BUILDDIR)/$(PRODUCT)

# begin compiler-dependent flags
#
# gcc flags:
#CXX := g++
#CXXFLAGS_DEBUG := -g
#CXXFLAGS_OPT := -O3
#CXXFLAGS_OPENMP := -fopenmp

# intel flags:
CXX := CC
CXXFLAGS_DEBUG := -g
CXXFLAGS_OPT := -O3 #-fast -fno-alias
CXXFLAGS_OPENMP := -fopenmp #-qopenmp -xCORE-AVX512 -qopt-zmm-usage=high

# pgi flags:
#CXX := pgCC
#CXXFLAGS_DEBUG := -g
#CXXFLAGS_OPT := -O3 -fastsse
#CXXFLAGS_OPENMP := -mp

# end compiler-dependent flags

# select optimized or debug
CXXFLAGS := $(CXXFLAGS_OPT) $(CXXFLAGS_DEBUG)
#CXXFLAGS := $(CXXFLAGS_DEBUG)

# add mpi to compile (comment out for serial build)
# the following assumes the existence of an mpi compiler
# wrapper called mpicxx
CXX := CC
CXXFLAGS += -DUSE_MPI

# add openmp flags (comment out for serial build)
CXXFLAGS += $(CXXFLAGS_OPENMP) 
#LDFLAGS := -Wno-unused-command-line-argument -L${MPICH_DIR}/../../../gtl/lib -lmpi_gtl_hsa -L$(MPICH_DIR)/lib -lmpi
LDFLAGS := -Wno-unused-command-line-argument -L$(MPICH_DIR)/lib -lmpi
LDFLAGS += $(CXXFLAGS_OPENMP) #-L/cray/css/users/kjt/opt/profiler/newest/ -lprofiler

LD := $(CXX)


# begin rules
all : $(BINARY)

-include $(DEPS)

$(BINARY) : $(OBJS)
	@echo linking $@
	$(maketargetdir)
	$(LD) -o $@ $^ $(LDFLAGS)

$(BUILDDIR)/%.o : $(SRCDIR)/%.cc
	@echo compiling $<
	$(maketargetdir)
	$(CXX) $(CXXFLAGS) $(CXXINCLUDES) -c -o $@ $<

$(BUILDDIR)/%.d : $(SRCDIR)/%.cc
	@echo making depends for $<
	$(maketargetdir)
	@$(CXX) $(CXXFLAGS) $(CXXINCLUDES) -M $< | sed "1s![^ \t]\+\.o!$(@:.d=.o) $@!" >$@

define maketargetdir
	-@mkdir -p $(dir $@) >/dev/null 2>&1
endef

.PHONY : clean
clean :
	rm -f $(BINARY) $(OBJS) $(DEPS)
