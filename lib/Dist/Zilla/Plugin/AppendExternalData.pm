use strict;
use warnings;
package Dist::Zilla::Plugin::AppendExternalData;
# ABSTRACT: Append data to gathered files
# VERSION

use Moose;
use Moose::Autobox;
use MooseX::Types::Path::Class qw(Dir File);
with(
  'Dist::Zilla::Role::FileMunger',
  'Dist::Zilla::Role::FilePruner',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ ':InstallModules', ':ExecFiles' ],
  },
);


use Path::Class;
use namespace::autoclean;

=attr source_dir (REQUIRED)

This is the directory containing data to append.
Files within this directory that have the same relative names as
modules and executables will have their contents appended.  E.g.
if C<source_dir> is F<pod>, then F<pod/lib/Foo.pm> will be appended
to F<lib/Foo.pm>.  If a gathered file does not match a file in the
source directory or vice-versa, it will not altered and is not
considered an error.

=cut

has source_dir => (
  is   => 'ro',
  isa  => Dir,
  coerce   => 1,
  required => 1,
);

=attr prune_source_dir

This is a boolean that indicates whether the C<source_dir> should also be
pruned from the distribution. The default is 1.

=cut

has prune_source_dir => (
  is   => 'ro',
  isa  => 'Bool',
  default  => 1,
);

sub prune_files {
  my ($self) = @_;

  return unless $self->prune_source_dir;

  my $source_dir = $self->source_dir;

  for my $file ($self->zilla->files->flatten) {
    next unless $file->name =~ m{\A$source_dir/}; 
    $self->log_debug([ 'pruning %s', $file->name ]);
    $self->zilla->prune_file($file);
  }

  return;
}

sub munge_files {
  my ($self) = @_;

  my $source_dir = $self->source_dir;

  for my $file ( @{ $self->found_files } ) {
    my $pod_file = file($source_dir, $file->name);
    next unless -e $pod_file;
    $self->munge_file($file, $pod_file);
  }
}

sub munge_file {
  my ($self, $file, $pod_file) = @_;
  $self->log_debug(
    [ 'appending Pod from %s to %s', $pod_file->stringify, $file->name ]
  );
  $file->content($file->content . "\n" . $pod_file->slurp);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=for Pod::Coverage prune_files munge_files munge_file

=begin wikidoc

= SYNOPSIS

  [AppendExternalData]
  source_dir = pod       ; required
  prune_source_dir = 1   ; default

= DESCRIPTION

This [Dist::Zilla] plugin appends files in a directory to files being
gathered for the distribution.

When using this plugin, be thoughtful about the order in which you want
files to be modified.  For example, if you are appending Pod, it makes
a big difference if you append before or after a plugin like
{PodWeaver}.  If you list this plugin first, the Pod will be appended
before weaving and the added Pod will wind up in the middle of the generated
Pod.  If this plugin is listed last, the Pod will be appended after
weaving and will follow the generated Pod from {PodWeaver}.

If appending a {__DATA__} section, be sure to put this plugin last
among plugins that modify your files.

= CAVEAT

This is a proof-of-concept and does not yet have any tests of its behavior.

=end wikidoc

=cut

