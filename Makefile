MADS ?= mads

random_test.xex: random.s random_test.s
	$(MADS) -o:random_test.xex random_test.s

clean:
	rm -f random_test.xex *~
