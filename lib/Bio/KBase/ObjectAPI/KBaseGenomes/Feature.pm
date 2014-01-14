########################################################################
# Bio::KBase::ObjectAPI::KBaseGenomes::Feature - This is the moose object corresponding to the Feature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseGenomes::DB::Feature;
package Bio::KBase::ObjectAPI::KBaseGenomes::Feature;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseGenomes::DB::Feature';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has genomeID => ( is => 'rw',printOrder => 2, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgenomeID' );
has roleList => ( is => 'rw',printOrder => 8, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildroleList' );
has compartments => ( is => 'rw',printOrder => -1, isa => 'ArrayRef', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcompartments' );
has comment => ( is => 'rw',printOrder => 2, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcomment' );
has delimiter => ( is => 'rw',printOrder => 2, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddelimiter' );
has roles  => ( is => 'rw', isa => 'ArrayRef',printOrder => -1, type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildroles' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildgenomeID {
	my ($self) = @_;
	return $self->parent()->id();
}
sub _buildroleList {
	my ($self) = @_;
	my $roleList = "";
	my $roles = $self->roles();
	for (my $i=0; $i < @{$roles}; $i++) {
		if (length($roleList) > 0) {
			$roleList .= ";";
		}
		$roleList .= $roles->[$i];
	}
	return $roleList;
}
sub _buildcompartments {
	my ($self) = @_;
	$self->_functionparse();
	return $self->compartments();
}
sub _buildcomment {
	my ($self) = @_;
	$self->_functionparse();
	return $self->comment();
}
sub _builddelimiter {
	my ($self) = @_;
	$self->_functionparse();
	return $self->delimiter();
}
sub _buildroles {
	my ($self) = @_;
	$self->_functionparse();
	return $self->roles();
}
sub _functionparse {
	my ($self) = @_;
	$self->compartments(["u"]);
	$self->roles([]);
	$self->delimiter("none");
	$self->comment("none");	
	my $compartmentTranslation = {
		"cytosolic" => "c",
		"plastidial" => "d",
		"mitochondrial" => "m",
		"peroxisomal" => "x",
		"lysosomal" => "l",
		"vacuolar" => "v",
		"nuclear" => "n",
		"plasma\\smembrane" => "p",
		"cell\\swall" => "w",
		"golgi\\sapparatus" => "g",
		"endoplasmic\\sreticulum" => "r",
		extracellular => "e",
	    cellwall => "w",
	    periplasm => "p",
	    cytosol => "c",
	    golgi => "g",
	    endoplasm => "r",
	    lysosome => "l",
	    nucleus => "n",
	    chloroplast => "h",
	    mitochondria => "m",
	    peroxisome => "x",
	    vacuole => "v",
	    plastid => "d",
	    unknown => "u"
	};
	my $function = $self->function();
	my $array = [split(/\#/,$function)];
	$function = shift(@{$array});
	$function =~ s/\s+$//;
	$self->comment(join("#",@{$array}));
	my $compHash = {};
	if (length($self->comment()) > 0) {
		foreach my $comp (keys(%{$compartmentTranslation})) {
			if ($self->comment() =~ /$comp/) {
				$compHash->{$compartmentTranslation->{$comp}} = 1;
			}
		}
	}
	if (keys(%{$compHash}) > 0) {
		$self->compartments([keys(%{$compHash})]);
	}
	if ($function =~ /\s*;\s/) {
		$self->delimiter(";");
	}
	if ($function =~ /s+\@\s+/) {
		$self->delimiter("\@");
	}
	if ($function =~ /s+\/\s+/) {
		$self->delimiter("/");
	}
	$self->roles([split(/\s*;\s+|\s+[\@\/]\s+/,$function)]);
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
