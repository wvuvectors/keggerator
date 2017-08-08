# INSTALL INSTRUCTIONS

### keggerator v1.0
[https://github.com/driscollmml/keggerator](https://github.com/driscollmml/keggerator)


## Installation
`keggerator` is built on Perl and Bash. It requires no special compilation or installation (but see **Dependencies** below).

1. Download or checkout the latest version of `keggerator` from [github](https://github.com/driscollmml/keggerator).
2. Unzip the downloaded file and move the resulting folder to a convenient location on your computer. If you checked out the repository instead, skip this step.
3. For ease of use, add the **keggerator/sbin/** folder to your PATH variable. *Do not remove or re-organize the files in **sbin**.*
4. Install the dependencies listed below.

## Dependencies
*keggerator* requires an Internet connection, a working shell (preferably Bash), and the following packages to function properly. Some simple UNIX knowledge will be helpful.

### [Perl v5.22.0](https://www.perl.org/get.html)

1. Use `perl -v` to check what version of Perl is active on your machine.

Perl is installed by default on almost all Linux and OS X systems. If you have no Perl on your machine, the easiest way to install it is using a package manager. Linux has many options: apt, rpm, yum are fairly popular. For macOS, we recommend [homebrew](https://brew.sh/). **Installing and compiling Perl from source is highly discouraged. We can not provide technical assistance in this regard.**

### [List::Util](http://search.cpan.org/~pevans/Scalar-List-Utils-1.48/lib/List/Util.pm)

List::Util is a Perl module that can be accessed via CPAN, the central Perl repository, using the link above. There are many ways to do this. If you have a system installation of Perl (likely), and sudo access (possibly), this is probably easiest:

1. `sudo perl -MCPAN -e shell`
2. `install List::Util`

If you have installed Perl yourself (for example, using a package manager like **homebrew**), or your Perl is not system-level (usually the case on remote servers), you can follow the same steps but probably don't need to sudo. Other options for installing Perl modules are [numerous](http://www.cpan.org/modules/INSTALL.html) [and](https://perlmaven.com/how-to-install-a-perl-module-from-cpan) [plentiful](http://www.thegeekstuff.com/2008/09/how-to-install-perl-modules-manually-and-using-cpan-command/) on the Internet.

### [Statistics::Basic](http://search.cpan.org/~jettero/Statistics-Basic-1.6611/lib/Statistics/Basic.pod)

Statistics::Basic is also a Perl module that can be accessed and installed just like List::Util.


