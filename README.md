# preseed

Far from perfect, but at least, i gain time when pxe is not available

* adjust config file
* sudo ./make_iso.sh
* as root, server the generated preseed file:
    * while true; do nc -vv -l -p 80 -q 1 < preseed.cfg ; done
