################################################################################
#
#   File name: StickyForms.pm
#   Project: HTML::StickyForms
#
#   Author: Peter Haworth
#   Date created: 06/06/2000
#
#   sccs version: 1.4    last changed: 06/15/00
#
#   Copyright Peter Haworth 2000
#   You may use and distribute this module according to the same terms
#   that Perl is distributed under.
#
################################################################################

package HTML::StickyForms;
use strict;
use vars qw(
  $VERSION
);

$VERSION=0.01;


################################################################################
# Class method: new($request)
# Description: Return a new HTML::StickyForms object
#	$request may be an instance of CGI (new or old) or Apache::Request
# Author: Peter Haworth
sub new{
  my($class,$req)=@_;

  my $type;
  if(!$req){
    $type='empty';
  }elsif(UNIVERSAL::isa($req,'Apache::Request')){
    $type='apreq';
  }elsif(UNIVERSAL::isa($req,'CGI') || UNIVERSAL::isa($req,'CGI::State')){
    $type='CGI';
  }else{
    # XXX Maybe this should die?
    return undef;
  }

  # Count submitted fields
  my $params=()=$type eq 'empty' ? () : $req->param;

  bless {
    req => $req,
    type => $type,
    params => $params,
  },$class;
}

################################################################################
# Method: trim_params()
# Description: Trim leading and trailing whitespace from all submitted values
# Author: Peter Haworth
sub trim_params{
  my($self)=@_;
  my $req=$self->{req};
  my $type=$self->{type};
  return if $type eq 'empty';

  foreach my $k($req->param){
    my @v=$req->param($k);
    my $changed;
    foreach(@v){
      $changed+= s/^\s+//s + s/\s+$//s;
    }
    if($changed){
      if($type eq 'apreq'){
	$req->param($k,\@v);
      }else{
	$req->param($k,@v)
      }
    }
  }
}

################################################################################
# Subroutine: _escape($string)
# Description: Escape HTML-special characters in $string
# Author: Peter Haworth
sub _escape($){
  $_[0]=~s/([<>&"\177-\377])/sprintf "&#%d;",ord $1/ge;
}

################################################################################
# Method: text(%args)
# Description: Return an HTML <INPUT type="text"> field
# Special %args elements:
#	type => TYPE attribute value, defaults to "text"
#	default => VALUE attribute value, if sticky values not present
# Author: Peter Haworth
sub text{
  my($self,%args)=@_;
  my $type=delete $args{type} || 'text';
  my $name=delete $args{name};
  my $value=delete $args{default};
  $value=$self->{req}->param($name) if $self->{params};

  _escape($name);
  _escape($value);

  my $field=qq(<INPUT TYPE="$type" NAME="$name" VALUE="$value");
  while(my($key,$val)=each %args){
    $field.=qq( $key="$val"); # XXX Escape?
  }

  return "$field>";
}

################################################################################
# Method: password(%args)
# Description: Return an HTML <INPUT type="password"> field
#	As text()
# Author: Peter Haworth
sub password{
  my $self=shift;
  $self->text(@_,type => 'password');
}

################################################################################
# Method: textarea(%args)
# Description: Return an HTML <TEXTAREA> tag
# Special %args elements:
#	default => field contents, if sticky values not present
# Author: Peter Haworth
sub textarea{
  my($self,%args)=@_;
  my $name=delete $args{name};
  my $value=delete $args{default};
  $value=$self->{req}->param($name) if $self->{params};

  _escape($name);
  _escape($value);

  my $field=qq(<TEXTAREA NAME="$name");
  while(my($key,$val)=each %args){
    $field.=qq( $key="$val"); # XXX Escape?
  }

  return "$field>$value</TEXTAREA>";
}

################################################################################
# Method: checkbox(%args)
# Description: Return a single HTML <INPUT type="checkbox"> tag
# Special %args elements:
#	checked => whether the box is checked, if sticky values not present
# Author: Peter Haworth
sub checkbox{
  my($self,%args)=@_;
  my $name=delete $args{name};
  my $value=delete $args{value};
  my $checked=delete $args{checked};
  $checked=$self->{req}->param($name) eq $value if $self->{params};

  _escape($name);
  _escape($value);

  my $field=qq(<INPUT TYPE="checkbox" NAME="$name" VALUE="$value");
  $field.=' CHECKED' if $checked;
  while(my($key,$val)=each %args){
    $field.=qq( $key="$val"); # XXX Escape?
  }

  return "$field>";
}

################################################################################
# Method: checkbox_group(%args)
# Description: Return a group of HTML <INPUT type="checkbox"> tags
# Special %args elements:
#	value/values => arrayref of field values, defaults to label keys
#	label/labels => hashref of field names, no default
#	escape => whether to escape HTML characters in labels
#	default/defaults => arrayref of selected values, if no sticky values
#	linebreak => whether to add <BR>s after each checkbox
# Author: Peter Haworth
sub checkbox_group{
  my($self,%args)=@_;
  my $name=delete $args{name};
  my $labels=delete $args{labels} || delete $args{label} || {};
  my $escape=delete $args{escape};
  my $values=delete $args{values} || delete $args{value} || [keys %$labels];
  my $defaults=delete $args{defaults} || delete $args{default} || [];
  my $br=delete $args{linebreak} ? '<BR>' : '';
  my %checked=map { ; $_ => 1 }
    $self->{params} ? $self->{req}->param($name) : @$defaults;

  _escape($name);

  my $field=qq(<INPUT TYPE="checkbox" NAME="$name");
  while(my($key,$val)=each %args){
    $field.=qq( $key="$val"); # XXX Escape?
  }

  my @checkboxes;
  for my $value(@$values){
    _escape(my $evalue=$value);
    my $field=qq($field VALUE="$evalue");
    $field.=" CHECKED" if $checked{$value};
    $field.='>';
    if((my $label=$labels->{$value})=~/\S/){
      _escape($label) if $escape;
      $field.=$label;
    }
    $field.=$br;
    push @checkboxes,$field;
  }

  return @checkboxes if wantarray;
  return join '',@checkboxes;
}

################################################################################
# Method: radio_group(%args)
# Description: Return a group of HTML <INPUT type="radio"> tags
# Special %args elements:
#	value/values => arrayref of field values, defaults to label keys
#	label/labels => hashref of field names, no default
#	escape => whether to escape HTML characters in labels
#	default => selected value, if no sticky values
#	linebreak => whether to add <BR>s after each checkbox
# Author: Peter Haworth
sub radio_group{
  my($self,%args)=@_;
  my $name=delete $args{name};
  my $labels=delete $args{labels} || delete $args{label} || {};
  my $escape=delete $args{escape};
  my $values=delete $args{values} || delete $args{value} || [keys %$labels];
  my $default=delete $args{default};
  $default=$self->{req}->param($name) if $self->{params};
  my $br=delete $args{linebreak} ? '<BR>' : '';

  _escape($name);

  my $field=qq(<INPUT TYPE="radio" NAME="$name");
  while(my($key,$val)=each %args){
    $field.=qq( $key="$val"); # XXX Escape?
  }

  my @radios;
  for my $value(@$values){
    _escape(my $evalue=$value);
    my $field=qq($field VALUE="$evalue");
    $field.=" CHECKED" if $default eq $value;
    $field.='>';
    if((my $label=$labels->{$value})=~/\S/){
      _escape($label) if $escape;
      $field.=$label;
    }
    $field.=$br;
    push @radios,$field;
  }

  return @radios if wantarray;
  return join '',@radios;
}

################################################################################
# Return true to require
1;


