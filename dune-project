(lang dune 3.12)
(name libdash)
(using ctypes 0.3)

(source (github mgree/libdash))
(license BSD-3-Clause)
(authors "Michael Greenberg")
(maintainers "michael@greenberg.science")

(package
 (name libdash)
 (synopsis "Bindings to the dash shell's parser")
 (depends
   ("ctypes" (>= "0.21.1"))
   ("ctypes-foreign" (>= "0.21.1"))
   ("atdgen" (>= "2.15.0"))
   ("conf-autoconf" (>= 0.1))
   ("conf-aclocal" (>= 2))
   ("conf-automake" (>= 1))
   ("conf-libtool" (>= 1))))

(generate_opam_files)