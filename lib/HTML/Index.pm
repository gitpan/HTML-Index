package HTML::Index;

#------------------------------------------------------------------------------
#
# Pragmas
#
#------------------------------------------------------------------------------

require 5.005_62;
use strict;
use warnings;

#------------------------------------------------------------------------------
#
# Modules
#
#------------------------------------------------------------------------------

use File::Find;
use File::Path;
use HTML::TreeBuilder;
use WWW::SimpleRobot;
use LWP::Simple;
use DB_File;
use Tie::TextDir;
use Fcntl;

use HTML::Index::SearchResults;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my %OPTIONS = (
    VERBOSE             => undef,
    SLEEP               => undef,
    STOP_WORD_FILE      => undef,
    DB_TYPE             => 'DB_File',
    DB_HASH_CACHESIZE   => 0,
    REFRESH             => 0,
    REMOTE              => 0,
    DEPTH               => undef,
    HTML_DIRS           => [ '.' ],
    IGNORE              => undef,
    URLS                => [],
    DB_DIR              => '.',
    EXTENSIONS_REGEX    => 's?html?',
);

my @DB_FILES = ( qw(
    file2fileid
    fileid2file
    word2wordid
    wordid2word
    fileid2wordid
    wordid2fileid
    fileid2modtime
) );

#------------------------------------------------------------------------------
#
# Private methods
#
#------------------------------------------------------------------------------

sub _get_new_file_id
{
    my $self = shift;

    $self->{DB_HASH}{fileid2file}{nextid} ||= 1;
    return $self->{DB_HASH}{fileid2file}{nextid}++;
}

sub _get_new_word_id
{
    my $self = shift;
    $self->{DB_HASH}{wordid2word}{nextid} ||= 1;
    return $self->{DB_HASH}{wordid2word}{nextid}++;
}

sub _get_word_id
{
    my $self = shift;
    my $word = shift;

    my $word_id = $self->{DB_HASH}{word2wordid}{$word};
    return $word_id if defined $word_id;
    $word_id = $self->_get_new_word_id();
    $self->{DB_HASH}{word2wordid}{$word} = $word_id;
    $self->{DB_HASH}{wordid2word}{$word_id} = $word;
    return $word_id;
}

sub _get_file_hash
{
    my $self = shift;
    my $word_id = shift;
    return () unless defined $self->{DB_HASH}{wordid2fileid}{$word_id};
    return split /,/, $self->{DB_HASH}{wordid2fileid}{$word_id};
}

sub _get_word_hash
{
    my $self = shift;
    my $file_id = shift;
    return () unless defined $self->{DB_HASH}{fileid2wordid}{$file_id};
    return split /,/, $self->{DB_HASH}{fileid2wordid}{$file_id};
}

sub _set_file_hash
{
    my $self = shift;
    my $word_id = shift;
    my $file_hash = shift;

    $self->{DB_HASH}{wordid2fileid}{$word_id} = join( ',', %$file_hash );
}

sub _set_word_hash
{
    my $self = shift;
    my $file_id = shift;
    my $word_hash = shift;

    $self->{DB_HASH}{fileid2wordid}{$file_id} = join( ',', %$word_hash );
}

sub _deindex
{
    my $self = shift;
    my $file_id = shift;

    $self->_verbose( "$file_id has changed - deindexing ...\n" );
    my %word_hash = $self->_get_word_hash( $file_id );
    # delete $file_id from all words in wordid2fileid
    for my $word_id ( keys %word_hash )
    {
        $self->_verbose( "\tremoving $file_id from $word_id ...\n" );
        my %file_hash = $self->_get_file_hash( $word_id );
        delete( $file_hash{$file_id} );
        # if there are no other files with this word, delete it
        if ( keys %file_hash ) 
        {
            $self->_set_file_hash( $word_id, \%file_hash );
        }
        else
        {
            $self->_verbose( "Deleting $word_id from the index\n" );
            delete( $self->{DB_HASH}{wordid2fileid}{$word_id} );
        }
    }
    my $file = $self->{DB_HASH}{fileid2file}{$file_id};
    $self->_verbose( "Deleting $file_id from fileid2file\n" );
    delete( $self->{DB_HASH}{fileid2file}{$file_id} );
    $self->_verbose( "Deleting $file_id from fileid2wordid\n" );
    delete( $self->{DB_HASH}{fileid2wordid}{$file_id} );
    $self->_verbose( "Deleting $file_id from fileid2modtime\n" );
    delete( $self->{DB_HASH}{fileid2modtime}{$file_id} );
    $self->_verbose( "Deleting $file from file2fileid\n" );
    delete( $self->{DB_HASH}{file2fileid}{$file} );
}

sub _verbose
{
    my $self = shift;

    return unless $self->{VERBOSE};
    print STDERR @_;
}

sub _tie
{
    my $self = shift;
    my $db_file = shift;
    my $mode = shift || 'r';

    die "Unknown mode: $mode" unless $mode =~ /^rw?$/;

    return if tied( %{$self->{DB_HASH}{$db_file}} );
    if ( $self->{DB_TYPE} eq 'DB_File' )
    {
        my $db_path = "$self->{DB_DIR}/$db_file.db";
        if ( -e $db_path and $self->{REFRESH} )
        {
            $self->_verbose( "Refreshing $db_file db\n" );
            unlink( $db_path ) or die "Can't remove $db_path\n";
        }
        my $m = $mode eq 'r' ? O_RDONLY : O_RDWR|O_CREAT;
        tie 
            %{$self->{DB_HASH}{$db_file}}, 
            'DB_File', $db_path, $m, 0644, $DB_HASH
            or die "Cannot tie database $db_path: $!\n"
        ;
    }
    elsif ( $self->{DB_TYPE} eq 'Tie::TextDir' )
    {
        my $db_path = "$self->{DB_DIR}/$db_file";
        if ( -e $db_path and $self->{REFRESH} )
        {
            $self->_verbose( "Refreshing $db_file db\n" );
            rmtree( $db_path ) or die "Can't remove $db_path\n";
        }
        tie %{$self->{DB_HASH}{$db_file}}, $self->{DB_TYPE}, $db_path, $mode,
            or die "Cannot tie database $db_path: $!\n"
        ;
    }
    else
    {
        die "Unknown DB_TYPE type $self->{DB_TYPE}\n";
    }
}

sub _untie
{
    my $self = shift;
    my $db_file = shift;

    return untie %{$self->{DB_HASH}{$db_file}};
}

sub _sync
{
    my $self = shift;
    my $db_file = shift;

    return if $self->{DB_TYPE} eq 'Tie::TextDir';
    my $tied = tied( %{$self->{DB_HASH}{$db_file}} );
    return $tied->sync;
}

sub _tie_db_files
{
    my $self = shift;
    my $mode = shift;

    $DB_HASH->{cachesize} = $self->{DB_HASH_CACHESIZE};

    for my $db_file ( @DB_FILES )
    {
        $self->_tie( $db_file, $mode );
    }
}

sub _create_stopword_list
{
    my $self = shift;

    return unless defined( $self->{STOP_WORD_FILE} );
    die "stopfile $self->{STOP_WORD_FILE} doesn't exist\n"
        unless -e $self->{STOP_WORD_FILE}
    ;
    die "can't read stopfile $self->{STOP_WORD_FILE}\n"
        unless -r $self->{STOP_WORD_FILE}
    ;
    open( STOPWORDS, $self->{STOP_WORD_FILE} );
    my @stopwords = <STOPWORDS>;
    _normalize( @stopwords );
    $self->{STOPWORD_HASH} = { map { $_ => 1 } @stopwords };
}

sub _create_file_list
{
    my $self = shift;

    $self->_verbose( 
        "Creating list of files to index in @{ $self->{HTML_DIRS} }...\n"
    );
    my @files;
    my $i = 0;
    find(
        sub {
            return if 
                defined( $self->{IGNORE} ) and 
                $File::Find::name =~ /$self->{IGNORE}/
            ;
            return unless -T;
            return unless /\.$self->{EXTENSIONS_REGEX}$/;
            my $file = $File::Find::name;
            $self->_verbose( "$i\r" );
            $i++;
            push( @files, $file );
        },
        @{$self->{HTML_DIRS}}
    );
    $self->_verbose( "$#files files to index\n" );
    $self->{FILES} = [ map { name => $_ }, @files ];
}

sub _create_url_list
{
    my $self = shift;

    $self->_verbose( 
        "Creating list of files to index from @{ $self->{URLS} }...\n"
    );
    $self->{FILES} = [];
    for my $url ( @{$self->{URLS}} )
    {
        $self->_verbose( "Creating a WWW::SimpleRobot for $url\n" );
        my $robot = WWW::SimpleRobot->new(
            URLS                => [ $url ],
            FOLLOW_REGEX        => "^$url",
            VERBOSE             => $self->{VERBOSE},
            DEPTH               => $self->{DEPTH},
        );
        $self->_verbose( "doing traversal ...\n" );
        $robot->traverse;
        push( @{$self->{FILES}}, @{$robot->{pages}} );
    }
}

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my %args = ( %OPTIONS, @_ );
    for ( keys %args )
    {
        die "Unknown option $_\n" unless exists $OPTIONS{$_};
    }

    my $self = bless \%args, $class;

    if ( $self->{REMOTE} )
    {
        unless ( ref( $self->{URLS} ) eq 'ARRAY' )
        {
            die "URLS option should be an ARRAY ref\n";
        }
        unless ( @{$self->{URLS}} )
        {
            die "no urls provided in URLS option\n";
        }
    }
    else
    {
        unless ( ref( $self->{HTML_DIRS} ) eq 'ARRAY' )
        {
            die "HTML_DIRS option should be an ARRAY ref\n";
        }
    }
    unless ( -d $self->{DB_DIR} )
    {
        mkdir( $self->{DB_DIR} ) or die "can't mkdir $self->{DB_DIR}: $!\n";
    }
    unless( $self->{DB_TYPE} =~ /(DB_File)|(Tie::TextDir)/ )
    {
        die "Unknown DB_TYPE type $self->{DB_TYPE}\n";
    }
    $self->_create_stopword_list();

    return $self;
}

#------------------------------------------------------------------------------
#
# Destructor
#
#------------------------------------------------------------------------------


sub DESTROY
{
    my $self = shift;

    $self->_verbose( "destroying $self\n" );
    for my $db_file ( @DB_FILES )
    {
        next unless tied %{$self->{DB_HASH}{$db_file}};
        $self->_verbose( "Untying $db_file ...\n" );
        $self->_untie( $db_file )
            or die "Cannot untie database $db_file: $!\n"
        ;
    }
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub keys
{
    my $self = shift;
    my $db_file = shift;

    $self->_tie( $db_file, 'r' );
    my @keys = keys %{$self->{DB_HASH}{$db_file}};
    return @keys;
}

sub values
{
    my $self = shift;
    my $db_file = shift;

    $self->_tie( $db_file, 'r' );
    my @values = values %{$self->{DB_HASH}{$db_file}};
    return @values;
}

sub delete
{
    my $self = shift;
    my $db_file = shift;
    my $key = shift;

    $self->_tie( $db_file, 'rw' );
    $self->_verbose( "delete $db_file {$key}\n" );
    my $ret = delete( $self->{DB_HASH}{$db_file}{$key} );
    $self->_verbose( "delete returned $ret\n" );
    $self->_untie( $db_file );
    return $ret;
}

sub value
{
    my $self = shift;
    my $db_file = shift;
    my $key = shift;

    $self->_tie( $db_file, 'r' );
    my $value = $self->{DB_HASH}{$db_file}{$key};
    return $value;
}

sub each
{
    my $self = shift;
    my $db_file = shift;

    $self->_tie( $db_file, 'r' );
    my @each = each( %{$self->{DB_HASH}{$db_file}} );
    unless( @each )
    {
        $self->_untie( $db_file );
    }
    return @each;
}

sub validate
{
    my $self = shift;
    my $level = shift || 1;

    my $valid = 1;

    $self->_verbose( "Checking file2fileid against fileid2file ...\n" );
    if ( $level & 1 )
    {
        print STDERR "Level 1 validation ...\n";
        while ( my( $file, $fileid ) = $self->each( 'file2fileid' ) )
        {
            if ( not defined $file or not $file =~ /\S/ )
            {
                die "file2fileid has a null entry for $file ($fileid)\n";
                $valid = 0;
            }
            if ( not defined( $fileid ) or not $fileid =~ /\S/ )
            {
                die "file2fileid{$file} is null ($fileid)\n";
                $valid = 0;
            }
            my $cross_ref_file = $self->value( 'fileid2file', $fileid );
            unless ( defined $cross_ref_file )
            {
                die "file2fileid{$file} = $fileid BUT fileid2file{$fileid} is undefined\n";
                $valid = 0;
            }
            else
            {
                $cross_ref_file =~ s/\//_/g;
                unless ( $cross_ref_file eq $file )
                {
                    die " file2fileid{$file} = $fileid BUT fileid2file{$fileid} = $cross_ref_file\n";
                    $valid = 0;
                }
            }
            $self->_verbose( "$file : $fileid ...\n" );
        }
        $self->_verbose( "Checking fileid2file against file2fileid ...\n" );
        while ( my( $fileid, $file ) = $self->each( 'fileid2file' ) )
        {
            next if $fileid eq 'nextid';
            $file =~ s/\//_/g;
            if ( not defined $fileid or not $fileid =~ /\S/ )
            {
                die "fileid2file has a null entry for $fileid ($file)\n";
                $valid = 0;
            }
            if ( not defined( $file ) or not $file =~ /\S/ )
            {
                die "fileid2file{$fileid} is null ($file)\n";
                $valid = 0;
            }
            my $cross_ref_fileid = $self->value( 'file2fileid', $file );
            unless ( defined $cross_ref_fileid )
            {
                die "fileid2file{$fileid} = $file BUT file2fileid{$file} is undefined\n";
                $valid = 0;
            }
            else
            {
                unless ( $cross_ref_fileid eq $fileid )
                {
                    die " fileid2file{$fileid} = $file BUT file2fileid{$file} = $cross_ref_fileid\n";
                    $valid = 0;
                }
            }
            $self->_verbose( "$fileid : $file ...\n" );
        }
        $self->_verbose( "Checking word2wordid against wordid2word ...\n" );
        while ( my( $word, $wordid ) = $self->each( 'word2wordid' ) )
        {
            if ( not defined $word or not $word =~ /\S/ )
            {
                die "word2wordid has a null entry for $word ($wordid)\n";
                $valid = 0;
            }
            if ( not defined( $wordid ) or not $wordid =~ /\S/ )
            {
                die "word2wordid{$word} is null ($wordid)\n";
                $valid = 0;
            }
            my $cross_ref_word = $self->value( 'wordid2word', $wordid );
            unless ( defined $cross_ref_word )
            {
                die "word2wordid{$word} = $wordid BUT wordid2word{$wordid} is undefined\n";
                $valid = 0;
            }
            else
            {
                unless ( $cross_ref_word eq $word )
                {
                    die " word2wordid{$word} = $wordid BUT wordid2word{$wordid} = $cross_ref_word\n";
                    $valid = 0;
                }
            }
            $self->_verbose( "$word : $wordid ...\n" );
        }
        $self->_verbose( "Checking wordid2word against word2wordid ...\n" );
        while ( my( $wordid, $word ) = $self->each( 'wordid2word' ) )
        {
            next if $wordid eq 'nextid';
            if ( not defined $wordid or not $wordid =~ /\S/ )
            {
                die "wordid2word has a null entry for $wordid ($word)\n";
                $valid = 0;
            }
            if ( not defined( $word ) or not $word =~ /\S/ )
            {
                die "wordid2word{$wordid} is null ($word)\n";
                $valid = 0;
            }
            my $cross_ref_wordid = $self->value( 'word2wordid', $word );
            unless ( defined $cross_ref_wordid )
            {
                die "wordid2word{$wordid} = $word BUT word2wordid{$word} is undefined\n";
                $valid = 0;
            }
            else
            {
                unless ( $cross_ref_wordid eq $wordid )
                {
                    die "wordid2word{$wordid} = $word BUT word2wordid{$word} = $cross_ref_wordid\n";
                    $valid = 0;
                }
            }
            $self->_verbose( "$wordid : $word ...\n" );
        }
    }
    if ( $level & 2 )
    {
        print STDERR "Level 2 validation ...\n";
        $self->_verbose( "Checking wordid2fileid against fileid2wordid ...\n" );
        while ( my( $wordid, $fileid ) = $self->each( 'wordid2fileid' ) )
        {
            my $word = $self->value( 'wordid2word', $wordid );
            if ( not defined $wordid or not $wordid =~ /\S/ )
            {
                die "wordid2fileid has a null entry for $wordid ($fileid)\n";
                $valid = 0;
            }
            if ( not defined( $fileid ) or not $fileid =~ /\S/ )
            {
                die "wordid2fileid{$wordid} is null ($fileid)\n";
                $valid = 0;
            }
            $self->_verbose( "Checking $word ($wordid) ...\n" );
            my %fileid = split( /,/, $fileid );
            for my $fid ( keys %fileid )
            {
                my $f = $self->value( 'fileid2file', $fid );
                $self->_verbose( "\tChecking $f ($fid) ...\n" );
                my $wid = $self->value( 'fileid2wordid', $fid );
                my %wid = split( /,/, $wid );
                my @wid = keys %wid;
                my @words = map { $self->value( 'wordid2word', $_ ) . " ($_)" } @wid;
                die "$f ($fid) in wordid2fileid{$wordid} ($fileid) but $word ($wordid) not in fileid2wordid{$fid} (@words)\n"
                    unless $wid{$wordid}
                ;
            }
        }
        $self->_verbose( "Checking fileid2wordid against wordid2fileid ...\n" );
        while ( my( $fileid, $wordid ) = $self->each( 'fileid2wordid' ) )
        {
            my $file = $self->value( 'fileid2file', $fileid );
            if ( not defined $fileid or not $fileid =~ /\S/ )
            {
                die "fileid2wordid has a null entry for $fileid ($wordid)\n";
                $valid = 0;
            }
            if ( not defined( $wordid ) or not $wordid =~ /\S/ )
            {
                die "fileid2wordid{$fileid} is null ($wordid)\n";
                $valid = 0;
            }
            $self->_verbose( "Checking $file ($fileid) ...\n" );
            my %wordid = split( /,/, $wordid );
            for my $wid ( keys %wordid )
            {
                my $w = $self->value( 'wordid2word', $wid );
                $self->_verbose( "\tChecking $w ($wid) ...\n" );
                my $fid = $self->value( 'wordid2fileid', $wid );
                my %fid = split( /,/, $fid );
                my @fid = keys %fid;
                my @files = map { $self->value( 'fileid2file', $_ ) . " ($_)" } @fid;
                die "$w ($wid) in fileid2wordid{$fileid} ($wordid) but $file ($fileid) not in wordid2fileid{$wid} (@files)\n"
                    unless $fid{$fileid}
                ;
            }
        }
    }
    if ( $level & 4 )
    {
        print STDERR "Level 3 validation ...\n";
        $self->_verbose( "Checking fileid2modtime ...\n" );
        while ( my( $fileid, $modtime ) = $self->each( 'fileid2modtime' ) )
        {
            my $file = $self->value( 'fileid2file', $fileid );
            die "$fileid in fileid2modtime but not in fileid2file\n"
                unless defined $file
            ;
            my $curr_modtime = ( stat( $file ) )[9];
            print "$file ($fileid) : $modtime : $curr_modtime\n";
        }
        while ( my( $fileid, $file ) = $self->each( 'fileid2file' ) )
        {
            my $modtime = $self->value( 'fileid2modtime', $fileid );
            die "$fileid in fileid2file but not in fileid2modtime\n"
                unless defined $modtime
            ;
            my $curr_modtime = ( stat( $file ) )[9];
            print "$file ($fileid) : $modtime : $curr_modtime\n";
        }
    }
    return $valid;
}

sub create_index
{
    my $self = shift;

    $self->_tie_db_files( 'rw' );
    if ( $self->{REMOTE} )
    {
        $self->_create_url_list();
    }
    else
    {
        $self->_create_file_list();
    }
    my $nfiles = $#{$self->{FILES}};
    my $i = 0;
    for my $file ( @{$self->{FILES}} )
    {
        $file->{name} = $file->{url} if $self->{REMOTE};
        $self->_verbose( "Processing $file->{name} ... ($i / $nfiles)\n" );
        $i++;
        my ( $curr_modtime, $url );
        if ( $self->{REMOTE} )
        {
            my $modified_time = $file->{modified_time};
            next unless $modified_time;
            $curr_modtime = $modified_time;
        }
        else
        {
            $curr_modtime = ( stat( $file->{name} ) )[9];
        }
        next unless defined $curr_modtime;
        $self->_verbose( "modtime of $file->{name} = $curr_modtime\n" );
        ( my $munged_file = $file->{name} ) =~ s/\//_/g;
        my $file_id = $self->{DB_HASH}{file2fileid}{$munged_file};
        if( defined $file_id )
        {
            $self->_verbose( "File id = $file_id ...\n" );
            my $prev_modtime = $self->{DB_HASH}{fileid2modtime}{$file_id};
            $self->_verbose( "Prev. modtime of $file->{name} = $prev_modtime\n" );
            if ( $prev_modtime == $curr_modtime )
            {
                $self->_verbose( "$file->{name} hasn't changed .. skipping\n" );
                next;
            }
            $self->{DB_HASH}{fileid2modtime}{$file_id} = $curr_modtime;
            $self->_deindex( $file_id );
        }
        else
        {
            $self->_verbose( "$file->{name} is new\n" );
        }
        $file_id = $self->_get_new_file_id();
        $self->_verbose( "New file id = $file_id for $file->{name} ...\n" );
        $self->{DB_HASH}{file2fileid}{$munged_file} = $file_id;
        $self->{DB_HASH}{fileid2file}{$file_id} = $file->{name};
        $self->{DB_HASH}{fileid2modtime}{$file_id} = $curr_modtime;
        $self->{DB_HASH}{fileid2wordid}{$file_id} = "";
        $self->_verbose( "Indexing $file->{name} ($file_id)\n" );
        my $tree = HTML::TreeBuilder->new();
        $self->_verbose( "Parse $file->{name}\n" );
        if ( $self->{REMOTE} )
        {
            my $html = get( $file->{name} );
            next unless $html;
            $tree->parse( $html );
        }
        else
        {
            $tree->parse_file( $file->{name} );
        }
        $self->_verbose( "Get word hash for $file_id\n" );
        $self->_verbose( "Get text from $tree\n" );
        my $text = join( ' ', _get_text_array( $tree ) );
        my @words = _normalize( split( /\s+/, $text ) );
        $self->_verbose( "$#words words ... " );
        @words = grep { not exists $self->{STOPWORD_HASH}{$_} } @words;
        $self->_verbose( "($#words after stopwords) ...\n" );
        my $i = 0;
        my %word_hash = $self->_get_word_hash( $file_id );
        for my $word ( @words )
        {
            $self->_verbose( "$i / $#words\r" );
            $i++;
            my $word_id = $self->_get_word_id( $word );
            $word_hash{$word_id}++;
            my %file_hash = $self->_get_file_hash( $word_id );
            $file_hash{$file_id}++;
            $self->_set_file_hash( $word_id, \%file_hash );
        }
        $self->_set_word_hash( $file_id, \%word_hash );
        $self->_verbose( "\n" );
        $tree->delete();
        $self->_verbose( "Sync'ing db_files\n" );
        for my $db_file ( @DB_FILES ) { $self->_sync( $db_file ); }
        if ( $self->{SLEEP} )
        {
            $self->_verbose( "Sleep for $self->{SLEEP} seconds ...\n" );
            sleep( $self->{SLEEP} );
        }
    }

    $self->_verbose( "done!\n" );

}

sub search
{
    my $self = shift;
    my %args = @_;

    my $words = $args{words};
    my $logic = $args{logic} || 'OR';

    die "ARRAY ref expected\n" unless ref( $words ) eq 'ARRAY';

    my @words = 
        grep { not exists $self->{STOPWORD_HASH}{$_ } }
        _normalize( @$words )
    ;

    for my $db_file ( @DB_FILES )
    {
        $self->_tie( $db_file, 'r' );
    }
    my %results;
    for my $word ( @words )
    {
        next if $self->{STOPWORD_HASH}{$word};
        my $word_id = $self->{DB_HASH}{word2wordid}{$word};
        next unless $word_id;
        my %file_hash = $self->_get_file_hash( $word_id );
        next unless %file_hash;
        $self->_verbose( "Looking up $word ...\n" );
        for ( keys %file_hash )
        {
            $results{$_}{$word}++;
        }
    }

    return 
        map { 
            HTML::Index::SearchResults->new(
                path => $self->{DB_HASH}{fileid2file}{$_},
                words => [ keys( %{$results{$_}} ) ],
            );
        }
        grep { 
            $logic eq 'OR' || 
            scalar( keys( %{$results{$_}} ) ) == scalar( @words ) 
        }
        keys %results
    ;
}

#------------------------------------------------------------------------------
#
# Private functions
#
#------------------------------------------------------------------------------

sub _normalize( @ )
{
    my @n;
    for ( @_ )
    {
        chomp;
        tr/A-Z/a-z/;
        s/[^a-z0-9]//g;
        next unless $_;
        next unless /[a-z]/;
        next unless /^.{2,}$/;
        push( @n, $_ );
    }
    return @n;
}

sub _get_text_array
{
    my $element = shift;
    my @text;

    for my $child ( $element->content_list )
    {
        if ( ref( $child ) )
        {
            next if $child->tag =~  /^(script|style)$/;
            push( @text, _get_text_array( $child ) );
        }
        else
        {
            push( @text, $child );
        }
    }

    return @text;
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index - Perl extension for indexing HTML files

=head1 SYNOPSIS

  use HTML::Index;
  
  $indexer = HTML::Indexer->new( %options );

  $indexer->create_index;

  @results = $indexer->search( 
    words => [ 'search', keywords' ],
    logic => 'OR',
  );

  for my $result ( @results )
  {
    print "words found: ", $result->words, "\n";
    print "path found on: ", $result->path, "\n";
  }

=head1 DESCRIPTION

HTML::Index is a simple module for indexing HTML files so that they can be
subsequently searched by keywords. It is looselly based on the indexer.pl
script in the O'Reilly "CGI Programming with Perl, 2nd Edition" book
(http://www.oreilly.com/catalog/cgi2/author.html).

Indexing is based on a list of directories passed to the constructor as one of
its options (HTML_DIRS). All files in these directories whose extensions match
the EXTENSIONS_REGEX are parsed using HTML::TreeBuilder and the word in those
pages added to the index. Words are stored lowercase, anything at least 2
characters long, and consist of alphanumerics ([a-z\d]{2,}).

Indexing is also possible in "remote" mode; here a list of URLs is provided,
and indexed files are grabbed via HTTP from these URLs, and all pages linked
from them. Only pages on the same site are indexed.

Indexes are stored in various database files. The default is to use Berkeley
DB, but the filesystem can be use if Berkeley DB is not installed using
Tie::TextDir.

The modification times of files in the index are stored, and they are
"re-inexed" if their modification time changes. Searches return results in no
particular order - it is up to the caller to re-order them appropriately!
Indexes can be run incrementally - only new or updated files will be indexed or
re-indexed.

=head1 OPTIONS

=over 4

=item DB_TYPE

This should be either 'DB_File' or 'Tie::TextDir' depending on what type of
database you want to use for the index (Berkeley DB or filesystem). Default is
'DB_File'.

=item VERBOSE

Print various bumpf to STDERR.

=item SLEEP

Specify a period in seconds to sleep between files when indexing. Helps to
prevent thrashing the server for large indexes.

=item STOP_WORD_FILE

Specify a file containing "stop words" to ignore when indexling. A sample
stopwords.txt file is included in this distribution. MAke sure you use the same
STOP_WORD_FILE for indexing and searching. Otherwise, if you submit a search
for a word that was in the stop word list when indexing (especially in a
combination search) you may not get the result you expect!

=item DB_HASH_CACHESIZE

Set the cachesize for the DB_File hashes. Default is 0.

=item REMOTE

Operate in "remote" mode; expects URLS rather than HTML_DIRS filesystem
paths, and index pages by grabbing them via HTTP. Links off the URLs listed are
followed so that these pages can also be indexed. Only "internal" links are
followed.

=item REFRESH

Boolean to regenerate the index from scratch.

=item HTML_DIRS

Specify a list of directories to index as an array ref. Defaults to [ '.' ].

=item URLS

Specify a list of URLs to index as an array ref. Defaults to [ ].

=item IGNORE

Specify a regex of HTML_DIRS to ignore.

=item DB_DIR

Specify a directory to store the Berkeley DB files. Defaults to '.'.

=item EXTENSIONS_REGEX

Specify a regex of file extension to match for HTML files to be indexed.
Defaults to 's?html?'.

=back

=head1 METHODS

=over 4

=item create_index

Does exactly what it says on the can.

=item search

Search the index, returning an array of L<HTML::Index::SearchResults> objects.
Takes two arguments:

=over 4

=item words

An array ref to the keywords to search on. Keywords are "normalized" in the
same way as words in the index (i.e. lowercase, only alphanumerics, at least 2
character).

=item logic

Either OR or AND. Determines how the search words are combined logically.
Default is AND.

=back

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
