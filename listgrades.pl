#!/usr/bin/perl

use warnings;
use strict;
use utf8;

binmode(STDOUT, ":utf8");

use WWW::Mechanize;
use HTML::Tree;

# DUALIS doesn't know about HTTP 30x status codes
# it only ever emits HTTP/200 with Refresh:-Headers
# or a refresh meta tag
sub do_refresh
{
    my $mech = shift;

    if ($mech->response and my $refresh = $mech->response->header('Refresh')) {
        my($delay, $uri) = split /;\s*url=/i, $refresh;

        $uri ||= $mech->uri; # No URL; reload current URL.

        $mech->get($uri);
        return 1;
    }

    if ($mech->content() =~ /<meta http-equiv="refresh" content="\d+;\s*url=([^"]*)"/i) {
        $mech->get($1);
        return 1;
    }

    return 0;
}
sub follow_refreshs
{
    my $mech = shift;
    while (do_refresh($mech)) {}
}

my $user = $ARGV[0];
my $pw = $ARGV[1];

my $url = 'https://dualis.dhbw.de/';

my $mech = WWW::Mechanize->new();
$mech->agent('DUALIS Grade Scraper / Watcher Bot (jonas@kuemmerlin.eu)');
$mech->add_header('Accept-Language' => 'de-DE');
$mech->get($url);
follow_refreshs($mech); # dualis kennt nur HTTP/200 mit refresh-Header oder Meta-Tag

$mech->form_name('cn_loginForm');
$mech->field('usrname', $user);
$mech->field('pass', $pw);
$mech->submit();
follow_refreshs($mech); # refresh nach POST...

# check if login succeeded
if (not ($mech->content =~ /Eingegangene Nachrichten:/)) {
    warn "Login Failed\n";
    exit 1;
}

$mech->follow_link(text => 'Prüfungsergebnisse');
follow_refreshs($mech);

# alle Semester der Reihe nach abrufen
$mech->form_id('semesterchange');
my ($semesterbox) = $mech->find_all_inputs(name => 'semester');
foreach my $semester ($semesterbox->possible_values) {
    $mech->field('semester', $semester);
    $mech->submit();
    follow_refreshs($mech);

    # in alle prüfungsfenster verzweigen
    foreach my $detaillink ($mech->find_all_links(text => 'Prüfungen')) {
        $mech->get($detaillink);

        my $html = HTML::Tree->new_from_content($mech->content);
        my $modul = $html->find_by_tag_name('h1')->as_trimmed_text;
        my $notentable = $html->find_by_tag_name('table'); # erste Tabelle
        my $header1 = '';
        my $header2 = '';
        foreach my $notentr ($notentable->find_by_tag_name('tr')) {
            my @notentd = $notentr->look_down(class => qr/tbdata/);
            my $head1td = $notentr->look_down(class => qr/level01/);
            my $head2td = $notentr->look_down(class => qr/level02/);
            if ($head1td) {
                $header1 = $head1td->as_trimmed_text;
            }
            if ($head2td) {
                $header2 = $head2td->as_trimmed_text;
            }
            if (@notentd) {
                my $pruef = $notentd[1]->as_trimmed_text;
                my $note = $notentd[3]->as_trimmed_text;

                print "$modul\t$header1\t$header2\t$pruef\t$note\n";
            }
        }

        $mech->back();
    }
}
