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
    '<?xml version="1.0" encoding="UTF-8"?><InvalidationBatch xmlns="http://cloudfront.amazonaws.com/doc/2015-04-17/"><Paths><Quantity>2</Quantity><Items><Path><![CDATA[/blog/some/document.pdf]]></Path><Path><![CDATA[/images/*]]></Path></Items></Paths><CallerReference>1438972482</CallerReference></InvalidationBatch>',
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
x-amz-date:20150807T153442Z

content-length;content-type;host;x-amz-date
64b09f3f2181c5d78ac37f12611e5a9ca0269a2da1dd515e8828e6165a8da029
EOEXPECTED
chomp $expected;

is $canonical_request, $expected, 'canonical request created successfully';

is(
    Digest::SHA::sha256_hex($canonical_request),
    '0e440187931192e5722a7c5f33e1d50fdca88abd548cb0963edcf7a4a991568f',
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
   'cbf1de94a5d9f9099dc7114d6083fa852cc7d4e12a93118b429bb6d36334d9c7',
   'v4 signature created successfully'
);


