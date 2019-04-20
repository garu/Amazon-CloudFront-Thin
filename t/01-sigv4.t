use strict;
use warnings;
use Test::More tests => 5;
use URI           ();
use HTTP::Headers ();
use Digest::SHA   ();

use Amazon::CloudFront::Thin;

my $url = URI->new('https://cloudfront.amazonaws.com/');

my @paths = qw(
    /blog/some/document.pdf
    /images/*
);
my $time = 1438972482; # <-- time()

my $content = Amazon::CloudFront::Thin::_create_xml_payload(\@paths, $time);

is(
    $content,
    '<?xml version="1.0" encoding="UTF-8"?><InvalidationBatch xmlns="http://cloudfront.amazonaws.com/doc/2018-11-05/"><Paths><Quantity>2</Quantity><Items><Path><![CDATA[/blog/some/document.pdf]]></Path><Path><![CDATA[/images/*]]></Path></Items></Paths><CallerReference>1438972482</CallerReference></InvalidationBatch>',
    'payload created successfully'
);

my ($formatted_date, $formatted_time) = Amazon::CloudFront::Thin::_format_date($time);

my $headers = HTTP::Headers->new(
    'Content-Length' => 312,
    'Content-Type'   => 'text/xml',
    'Host'           => $url->host,
    'X-Amz-Date'     => $formatted_date . 'T' . $formatted_time . 'Z',
);

my $canonical_request = Amazon::CloudFront::Thin::_create_canonical_request(
    $url, $headers, $content
);

my $expected = <<'EOEXPECTED';
POST
/

content-length:312
content-type:text/xml
host:cloudfront.amazonaws.com
x-amz-date:20150807T183442Z

content-length;content-type;host;x-amz-date
e68a9818cc606b49cc85f99ef4c017b49f97624595ead70620e33b5351a41f1b
EOEXPECTED
chomp $expected;

is $canonical_request, $expected, 'canonical request created successfully';

is(
    Digest::SHA::sha256_hex($canonical_request),
    'eab4bd0ac0b1c0edbc40e37a078e7b9df17be63232ac042831b5276deed9f6dc',
    'sha256 matches canonical request'
);

my $string_to_sign = Amazon::CloudFront::Thin::_create_string_to_sign(
    $headers, $canonical_request
);

my ($date) = Amazon::CloudFront::Thin::_format_date($time);
is $date, '20150807', 'date stamp was properly formatted';

is(
    Amazon::CloudFront::Thin::_create_signature(
        'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        $string_to_sign,
        $date
    ),
    '1229c5a8f2077195cdfe9edf514af4f7e33d4120fdce00b3ce5a3146e166e2a3',
    'v4 signature created successfully'
);
