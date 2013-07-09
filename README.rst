openbel.rb
==========

JRuby prototype for managing and analyzing knowledge networks from BEL knowledge.

getting started
---------------

The wonderful `rbenv` tool sets up JRuby + gems.  The `scripts/bootstrap.sh`
shell script does all the magic but you'll need the following in your bash
configuration:

.. code-block:: ruby

  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile (or ~/.bashrc)
  echo 'eval "$(rbenv init -)"' >> ~/.bash_profile (or ~/.bashrc)

Then run:

.. code-block:: ruby

  scripts/bootstrap.sh

More info at rbenv_.

.. _rbenv: https://github.com/sstephenson/rbenv
