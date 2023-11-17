MADS ?= mads

all: random_test1.xex random_test2.xex

random_test1.xex: random.s random_test.s macros.s
	$(MADS) -d:TEST_BATCH1 -o:random_test1.xex random_test.s

random_test2.xex: random.s random_test.s macros.s
	$(MADS) -d:TEST_BATCH2 -o:random_test2.xex random_test.s

clean:
	rm -f random_test*.xex *~
