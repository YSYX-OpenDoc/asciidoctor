# frozen_string_literal: true
require_relative 'test_helper'

context 'Tables' do
  context 'PSV' do
    test 'converts simple psv table' do
      input = <<~'EOS'
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      cells = [%w(A B C), %w(a b c), %w(1 2 3)]
      doc = document_from_string input, standalone: false
      table = doc.blocks[0]
      assert_equal 100, table.columns.map {|col| col.attributes['colpcwidth'] }.reduce(:+)
      output = doc.convert
      assert_css 'table', output, 1
      assert_css 'table.tableblock.frame-all.grid-all.stretch', output, 1
      assert_css 'table > colgroup > col[style*="width: 33.3333%"]', output, 2
      assert_css 'table > colgroup > col:last-of-type[style*="width: 33.3334%"]', output, 1
      assert_css 'table tr', output, 3
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table td', output, 9
      assert_css 'table > tbody > tr > td.tableblock.halign-left.valign-top > p.tableblock', output, 9
      cells.each_with_index do |row, rowi|
        assert_css "table > tbody > tr:nth-child(#{rowi + 1}) > td", output, row.size
        assert_css "table > tbody > tr:nth-child(#{rowi + 1}) > td > p", output, row.size
        row.each_with_index do |cell, celli|
          assert_xpath "(//tr)[#{rowi + 1}]/td[#{celli + 1}]/p[text()='#{cell}']", output, 1
        end
      end
    end

    test 'should add direction CSS class if float attribute is set on table' do
      input = <<~'EOS'
      [float=left]
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS

      output = convert_string_to_embedded input
      assert_css 'table.left', output, 1
    end

    test 'should set stripes class if stripes option is set' do
      input = <<~'EOS'
      [stripes=odd]
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS

      output = convert_string_to_embedded input
      assert_css 'table.stripes-odd', output, 1
    end

    test 'outputs a caption on simple psv table' do
      input = <<~'EOS'
      .Simple psv table
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/table/caption[@class="title"][text()="Table 1. Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'only increments table counter for tables that have a title' do
      input = <<~'EOS'
      .First numbered table
      |=======
      |1 |2 |3
      |=======

      |=======
      |4 |5 |6
      |=======

      .Second numbered table
      |=======
      |7 |8 |9
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_css 'table:root', output, 3
      assert_xpath '(/table)[1]/caption', output, 1
      assert_xpath '(/table)[1]/caption[text()="Table 1. First numbered table"]', output, 1
      assert_xpath '(/table)[2]/caption', output, 0
      assert_xpath '(/table)[3]/caption', output, 1
      assert_xpath '(/table)[3]/caption[text()="Table 2. Second numbered table"]', output, 1
    end

    test 'uses explicit caption in front of title in place of default caption and number' do
      input = <<~'EOS'
      [caption="All the Data. "]
      .Simple psv table
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/table/caption[@class="title"][text()="All the Data. Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'disables caption when caption attribute on table is empty' do
      input = <<~'EOS'
      [caption=]
      .Simple psv table
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/table/caption[@class="title"][text()="Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'disables caption when caption attribute on table is empty string' do
      input = <<~'EOS'
      [caption=""]
      .Simple psv table
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/table/caption[@class="title"][text()="Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'disables caption on table when table-caption document attribute is unset' do
      input = <<~'EOS'
      :!table-caption:

      .Simple psv table
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_xpath '/table/caption[@class="title"][text()="Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'ignores escaped separators' do
      input = <<~'EOS'
      |===
      |A \| here| a \| there
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr > td', output, 2
      assert_xpath '/table/tbody/tr/td[1]/p[text()="A | here"]', output, 1
      assert_xpath '/table/tbody/tr/td[2]/p[text()="a | there"]', output, 1
    end

    test 'preserves escaped delimiters at the end of the line' do
      input = <<~'EOS'
      [%header,cols="1,1"]
      |===
      |A |B\|
      |A1 |B1\|
      |A2 |B2\|
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr:nth-child(1) > th', output, 2
      assert_xpath '/table/thead/tr[1]/th[2][text()="B|"]', output, 1
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[2]/p[text()="B1|"]', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 2
      assert_xpath '/table/tbody/tr[2]/td[2]/p[text()="B2|"]', output, 1
    end

    test 'should treat trailing pipe as an empty cell' do
      input = <<~'EOS'
      |===
      |A1 |
      |B1 |B2
      |C1 |C2
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A1"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 0
      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="B1"]', output, 1
    end

    test 'should auto recover with warning if missing leading separator on first cell' do
      input = <<~'EOS'
      |===
      A | here| a | there
      | x
      | y
      | z
      | end
      |===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table > tbody > tr', output, 2
        assert_css 'table > tbody > tr > td', output, 8
        assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A"]', output, 1
        assert_xpath '/table/tbody/tr[1]/td[2]/p[text()="here"]', output, 1
        assert_xpath '/table/tbody/tr[1]/td[3]/p[text()="a"]', output, 1
        assert_xpath '/table/tbody/tr[1]/td[4]/p[text()="there"]', output, 1
        assert_message logger, :ERROR, '<stdin>: line 2: table missing leading separator; recovering automatically', Hash
      end
    end

    test 'performs normal substitutions on cell content' do
      input = <<~'EOS'
      :show_title: Cool new show
      |===
      |{show_title} |Coming soon...
      |===
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//tbody/tr/td[1]/p[text()="Cool new show"]', output, 1
      assert_xpath %(//tbody/tr/td[2]/p[text()='Coming soon#{decode_char 8230}#{decode_char 8203}']), output, 1
    end

    test 'should only substitute specialchars for literal table cells' do
      input = <<~'EOS'
      |===
      l|one
      *two*
      three
      <four>
      |===
      EOS
      output = convert_string_to_embedded input
      result = xmlnodes_at_xpath('/table//pre', output, 1)
      assert_equal %(<pre>one\n*two*\nthree\n&lt;four&gt;</pre>), result.to_s
    end

    test 'should preserving leading spaces but not leading newlines or trailing spaces in literal table cells' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [cols=2*]
      |===
      l|
        one
        two
      three

        | normal
      |===
      EOS
      output = convert_string_to_embedded input
      result = xmlnodes_at_xpath('/table//pre', output, 1)
      assert_equal %(<pre>  one\n  two\nthree</pre>), result.to_s
    end

    test 'should ignore v table cell style' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [cols=2*]
      |===
      v|
        one
        two
      three

        | normal
      |===
      EOS
      output = convert_string_to_embedded input
      result = xmlnodes_at_xpath('/table//p[@class="tableblock"]', output, 1)
      assert_equal %(<p class="tableblock">one\n  two\nthree</p>), result.to_s
    end

    test 'table and column width not assigned when autowidth option is specified' do
      input = <<~'EOS'
      [options="autowidth"]
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table.fit-content', output, 1
      assert_css 'table[style*="width"]', output, 0
      assert_css 'table colgroup col', output, 3
      assert_css 'table colgroup col[style*="width"]', output, 0
    end

    test 'does not assign column width for autowidth columns in HTML output' do
      input = <<~'EOS'
      [cols="15%,3*~"]
      |=======
      |A |B |C |D
      |a |b |c |d
      |1 |2 |3 |4
      |=======
      EOS
      doc = document_from_string input
      table_row0 = doc.blocks[0].rows.body[0]
      assert_equal 15, table_row0[0].attributes['width']
      assert_equal 15, table_row0[0].attributes['colpcwidth']
      refute_equal '', table_row0[0].attributes['autowidth-option']
      expected_pcwidths = { 1 => 28.3333, 2 => 28.3333, 3 => 28.3334 }
      (1..3).each do |i|
        assert_equal 28.3333, table_row0[i].attributes['width']
        assert_equal expected_pcwidths[i], table_row0[i].attributes['colpcwidth']
        assert_equal '', table_row0[i].attributes['autowidth-option']
      end
      output = doc.convert standalone: false
      assert_css 'table', output, 1
      assert_css 'table colgroup col', output, 4
      assert_css 'table colgroup col[style]', output, 1
      assert_css 'table colgroup col[style*="width: 15%"]', output, 1
    end

    test 'can assign autowidth to all columns even when table has a width' do
      input = <<~'EOS'
      [cols="4*~",width=50%]
      |=======
      |A |B |C |D
      |a |b |c |d
      |1 |2 |3 |4
      |=======
      EOS
      doc = document_from_string input
      table_row0 = doc.blocks[0].rows.body[0]
      (0..3).each do |i|
        assert_equal 25, table_row0[i].attributes['width']
        assert_equal 25, table_row0[i].attributes['colpcwidth']
        assert_equal '', table_row0[i].attributes['autowidth-option']
      end
      output = doc.convert standalone: false
      assert_css 'table', output, 1
      assert_css 'table[style*="width: 50%"]', output, 1
      assert_css 'table colgroup col', output, 4
      assert_css 'table colgroup col[style]', output, 0
    end

    test 'equally distributes remaining column width to autowidth columns in DocBook output' do
      input = <<~'EOS'
      [cols="15%,3*~"]
      |=======
      |A |B |C |D
      |a |b |c |d
      |1 |2 |3 |4
      |=======
      EOS
      output = convert_string_to_embedded input, backend: 'docbook5'
      assert_css 'tgroup[cols="4"]', output, 1
      assert_css 'tgroup colspec', output, 4
      assert_css 'tgroup colspec[colwidth]', output, 4
      assert_css 'tgroup colspec[colwidth="15*"]', output, 1
      assert_css 'tgroup colspec[colwidth="28.3333*"]', output, 2
      assert_css 'tgroup colspec[colwidth="28.3334*"]', output, 1
    end

    test 'should compute column widths based on pagewidth when width is set on table in DocBook output' do
      input = <<~'EOS'
      :pagewidth: 500

      [width=50%]
      |=======
      |A |B |C |D

      |a |b |c |d
      |1 |2 |3 |4
      |=======
      EOS
      output = convert_string_to_embedded input, backend: 'docbook5'
      assert_css 'tgroup[cols="4"]', output, 1
      assert_css 'tgroup colspec', output, 4
      assert_css 'tgroup colspec[colwidth]', output, 4
      assert_css 'tgroup colspec[colwidth="62.5*"]', output, 4
    end

    test 'explicit table width is used even when autowidth option is specified' do
      input = <<~'EOS'
      [%autowidth,width=75%]
      |=======
      |A |B |C
      |a |b |c
      |1 |2 |3
      |=======
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table[style*="width"]', output, 1
      assert_css 'table colgroup col', output, 3
      assert_css 'table colgroup col[style*="width"]', output, 0
    end

    test 'first row sets number of columns when not specified' do
      input = <<~'EOS'
      |===
      |first |second |third |fourth
      |1 |2 |3
      |4
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 4
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 4
    end

    test 'colspec attribute using asterisk syntax sets number of columns' do
      input = <<~'EOS'
      [cols="3*"]
      |===
      |A |B |C |a |b |c |1 |2 |3
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'table with explicit column count can have multiple rows on a single line' do
      input = <<~'EOS'
      [cols="3*"]
      |===
      |one |two
      |1 |2 |a |b
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
    end

    test 'table with explicit deprecated colspec syntax can have multiple rows on a single line' do
      input = <<~'EOS'
      [cols="3"]
      |===
      |one |two
      |1 |2 |a |b
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
    end

    test 'columns are added for empty records in colspec attribute' do
      input = <<~'EOS'
      [cols="<,"]
      |===
      |one |two
      |1 |2 |a |b
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'cols may be separated by semi-colon instead of comma' do
      input = <<~'EOS'
      [cols="1s;3m"]
      |===
      | strong
      | mono
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 25%;"]', output, 1
      assert_css 'col[style="width: 75%;"]', output, 1
      assert_xpath '(//td)[1]//strong', output, 1
      assert_xpath '(//td)[2]//code', output, 1
    end

    test 'cols attribute may include spaces' do
      input = <<~'EOS'
      [cols=" 1, 1 "]
      |===
      |one |two |1 |2 |a |b
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 50%;"]', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'blank cols attribute should be ignored' do
      input = <<~'EOS'
      [cols=" "]
      |===
      |one |two
      |1 |2 |a |b
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 50%;"]', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'empty cols attribute should be ignored' do
      input = <<~'EOS'
      [cols=""]
      |===
      |one |two
      |1 |2 |a |b
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 50%;"]', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'table with header and footer' do
      input = <<~'EOS'
      [options="header,footer"]
      |===
      |Item       |Quantity
      |Item 1     |1
      |Item 2     |2
      |Item 3     |3
      |Total      |6
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tfoot', output, 1
      assert_css 'table > tfoot > tr', output, 1
      assert_css 'table > tfoot > tr > td', output, 2
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
      table_section_names = (xmlnodes_at_css 'table > *', output).map(&:node_name).select {|n| n.start_with? 't' }
      assert_equal %w(thead tbody tfoot), table_section_names
    end

    test 'table with header and footer docbook' do
      input = <<~'EOS'
      .Table with header, body and footer
      [options="header,footer"]
      |===
      |Item       |Quantity
      |Item 1     |1
      |Item 2     |2
      |Item 3     |3
      |Total      |6
      |===
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_css 'table', output, 1
      assert_css 'table > title', output, 1
      assert_css 'table > tgroup', output, 1
      assert_css 'table > tgroup[cols="2"]', output, 1
      assert_css 'table > tgroup[cols="2"] > colspec', output, 2
      assert_css 'table > tgroup[cols="2"] > colspec[colwidth="50*"]', output, 2
      assert_css 'table > tgroup > thead', output, 1
      assert_css 'table > tgroup > thead > row', output, 1
      assert_css 'table > tgroup > thead > row > entry', output, 2
      assert_css 'table > tgroup > thead > row > entry > simpara', output, 0
      assert_css 'table > tgroup > tfoot', output, 1
      assert_css 'table > tgroup > tfoot > row', output, 1
      assert_css 'table > tgroup > tfoot > row > entry', output, 2
      assert_css 'table > tgroup > tfoot > row > entry > simpara', output, 2
      assert_css 'table > tgroup > tbody', output, 1
      assert_css 'table > tgroup > tbody > row', output, 3
      assert_css 'table > tgroup > tbody > row', output, 3
      table_section_names = (xmlnodes_at_css 'table > tgroup > *', output).map(&:node_name).select {|n| n.start_with? 't' }
      assert_equal %w(thead tbody tfoot), table_section_names
    end

    test 'should set horizontal and vertical alignment when converting to DocBook' do
      input = <<~'EOS'
      |===
      |A ^.^|B >|C

      |A1
      ^.^|B1
      >|C1
      |===
      EOS
      output = convert_string input, backend: 'docbook'
      assert_css 'informaltable', output, 1
      assert_css 'informaltable thead > row > entry[align="left"][valign="top"]', output, 1
      assert_css 'informaltable thead > row > entry[align="center"][valign="middle"]', output, 1
      assert_css 'informaltable thead > row > entry[align="right"][valign="top"]', output, 1
      assert_css 'informaltable tbody > row > entry[align="left"][valign="top"]', output, 1
      assert_css 'informaltable tbody > row > entry[align="center"][valign="middle"]', output, 1
      assert_css 'informaltable tbody > row > entry[align="right"][valign="top"]', output, 1
    end

    test 'should preserve frame value ends when converting to HTML' do
      input = <<~'EOS'
      [frame=ends]
      |===
      |A |B |C
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table.frame-ends', output, 1
    end

    test 'should normalize frame value topbot as ends when converting to HTML' do
      input = <<~'EOS'
      [frame=topbot]
      |===
      |A |B |C
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table.frame-ends', output, 1
    end

    test 'should preserve frame value topbot when converting to DocBook' do
      input = <<~'EOS'
      [frame=topbot]
      |===
      |A |B |C
      |===
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_css 'informaltable[frame="topbot"]', output, 1
    end

    test 'should convert frame value ends to topbot when converting to DocBook' do
      input = <<~'EOS'
      [frame=ends]
      |===
      |A |B |C
      |===
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_css 'informaltable[frame="topbot"]', output, 1
    end

    test 'table with landscape orientation in DocBook' do
      ['orientation=landscape', '%rotate'].each do |attrs|
        input = <<~EOS
        [#{attrs}]
        |===
        |Column A | Column B | Column C
        |===
        EOS

        output = convert_string_to_embedded input, backend: 'docbook'
        assert_css 'informaltable', output, 1
        assert_css 'informaltable[orient="land"]', output, 1
      end
    end

    test 'table with implicit header row' do
      input = <<~'EOS'
      |===
      |Column 1 |Column 2

      |Data A1
      |Data B1

      |Data A2
      |Data B2
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 2
    end

    test 'table with implicit header row only' do
      input = <<~'EOS'
      |===
      |Column 1 |Column 2

      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tbody', output, 0
    end

    test 'table with implicit header row when other options set' do
      input = <<~'EOS'
      [%autowidth]
      |===
      |Column 1 |Column 2

      |Data A1
      |Data B1
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table[style*="width"]', output, 0
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 1
    end

    test 'no implicit header row if second line not blank' do
      input = <<~'EOS'
      |===
      |Column 1 |Column 2
      |Data A1
      |Data B1

      |Data A2
      |Data B2
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'no implicit header row if cell in first line spans multiple lines' do
      input = <<~'EOS'
      [cols=2*]
      |===
      |A1


      A1 continued|B1

      |A2
      |B2
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 2
      assert_xpath '(//td)[1]/p', output, 2
    end

    test 'should format first cell as literal if there is no implicit header row and column has l style' do
      input = <<~'EOS'
      [cols="1l,1"]
      |===
      |literal
      |normal
      |===
      EOS

      output = convert_string_to_embedded input
      assert_css 'tbody pre', output, 1
      assert_css 'tbody p.tableblock', output, 1
    end

    test 'should format first cell as AsciiDoc if there is no implicit header row and column has a style' do
      input = <<~'EOS'
      [cols="1a,1"]
      |===
      | * list
      | normal
      |===
      EOS

      output = convert_string_to_embedded input
      assert_css 'tbody .ulist', output, 1
      assert_css 'tbody p.tableblock', output, 1
    end

    test 'should interpret leading indent if first cell is AsciiDoc and there is no implicit header row' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [cols="1a,1"]
      |===
      |
        literal
      | normal
      |===
      EOS

      output = convert_string_to_embedded input
      assert_css 'tbody pre', output, 1
      assert_css 'tbody p.tableblock', output, 1
    end

    test 'should format first cell as AsciiDoc if there is no implicit header row and cell has a style' do
      input = <<~'EOS'
      |===
      a| * list
      | normal
      |===
      EOS

      output = convert_string_to_embedded input
      assert_css 'tbody .ulist', output, 1
      assert_css 'tbody p.tableblock', output, 1
    end

    test 'no implicit header row if AsciiDoc cell in first line spans multiple lines' do
      input = <<~'EOS'
      [cols=2*]
      |===
      a|contains AsciiDoc content

      * a
      * b
      * c
      a|contains no AsciiDoc content

      just text
      |A2
      |B2
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 2
      assert_xpath '(//td)[1]//ul', output, 1
    end

    test 'no implicit header row if first line blank' do
      input = <<~'EOS'
      |===

      |Column 1 |Column 2

      |Data A1
      |Data B1

      |Data A2
      |Data B2

      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'no implicit header row if noheader option is specified' do
      input = <<~'EOS'
      [%noheader]
      |===
      |Column 1 |Column 2

      |Data A1
      |Data B1

      |Data A2
      |Data B2
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'styles not applied to header cells' do
      input = <<~'EOS'
      [cols="1h,1s,1e",options="header,footer"]
      |===
      |Name |Occupation| Website
      |Octocat |Social coding| https://github.com
      |Name |Occupation| Website
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > thead > tr > th', output, 3
      assert_css 'table > thead > tr > th > *', output, 0

      assert_css 'table > tfoot > tr > th', output, 1
      assert_css 'table > tfoot > tr > td', output, 2
      assert_css 'table > tfoot > tr > td > p > strong', output, 1
      assert_css 'table > tfoot > tr > td > p > em', output, 1

      assert_css 'table > tbody > tr > th', output, 1
      assert_css 'table > tbody > tr > td', output, 2
      assert_css 'table > tbody > tr > td > p.header', output, 0
      assert_css 'table > tbody > tr > td > p > strong', output, 1
      assert_css 'table > tbody > tr > td > p > em > a', output, 1
    end

    test 'should apply text formatting to cells in implicit header row when column has a style' do
      input = <<~'EOS'
      [cols="2*a"]
      |===
      | _foo_ | *bar*

      | * list item
      | paragraph
      |===
      EOS
      output = convert_string_to_embedded input
      assert_xpath '(//thead/tr/th)[1]/em[text()="foo"]', output, 1
      assert_xpath '(//thead/tr/th)[2]/strong[text()="bar"]', output, 1
      assert_css 'tbody .ulist', output, 1
      assert_css 'tbody .paragraph', output, 1
    end

    test 'should apply style and text formatting to cells in first row if no implicit header' do
      input = <<~'EOS'
      [cols="s,e"]
      |===
      | _strong_ | *emphasis*
      | strong
      | emphasis
      |===
      EOS
      output = convert_string_to_embedded input
      assert_xpath '((//tbody/tr)[1]/td)[1]//strong/em[text()="strong"]', output, 1
      assert_xpath '((//tbody/tr)[1]/td)[2]//em/strong[text()="emphasis"]', output, 1
      assert_xpath '((//tbody/tr)[2]/td)[1]//strong[text()="strong"]', output, 1
      assert_xpath '((//tbody/tr)[2]/td)[2]//em[text()="emphasis"]', output, 1
    end

    test 'vertical table headers use th element instead of header class' do
      input = <<~'EOS'
      [cols="1h,1s,1e"]
      |===

      |Name |Occupation| Website

      |Octocat |Social coding| https://github.com

      |Name |Occupation| Website

      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > tbody > tr > th', output, 3
      assert_css 'table > tbody > tr > td', output, 6
      assert_css 'table > tbody > tr .header', output, 0
      assert_css 'table > tbody > tr > td > p > strong', output, 3
      assert_css 'table > tbody > tr > td > p > em', output, 3
      assert_css 'table > tbody > tr > td > p > em > a', output, 1
    end

    test 'supports horizontal and vertical source data with blank lines and table header' do
      input = <<~'EOS'
      .Horizontal and vertical source data
      [width="80%",cols="3,^2,^2,10",options="header"]
      |===
      |Date |Duration |Avg HR |Notes

      |22-Aug-08 |10:24 | 157 |
      Worked out MSHR (max sustainable heart rate) by going hard
      for this interval.

      |22-Aug-08 |23:03 | 152 |
      Back-to-back with previous interval.

      |24-Aug-08 |40:00 | 145 |
      Moderately hard interspersed with 3x 3min intervals (2 min
      hard + 1 min really hard taking the HR up to 160).

      I am getting in shape!

      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table[style*="width: 80%"]', output, 1
      assert_xpath '/table/caption[@class="title"][text()="Table 1. Horizontal and vertical source data"]', output, 1
      assert_css 'table > colgroup > col', output, 4
      assert_css 'table > colgroup > col:nth-child(1)[style*="width: 17.647%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(2)[style*="width: 11.7647%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(3)[style*="width: 11.7647%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(4)[style*="width: 58.8236%"]', output, 1
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 4
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 4
      assert_xpath "/table/tbody/tr[1]/td[4]/p[text()='Worked out MSHR (max sustainable heart rate) by going hard\nfor this interval.']", output, 1
      assert_css 'table > tbody > tr:nth-child(3) > td:nth-child(4) > p', output, 2
      assert_xpath '/table/tbody/tr[3]/td[4]/p[2][text()="I am getting in shape!"]', output, 1
    end

    test 'percentages as column widths' do
      input = <<~'EOS'
      [cols="<.^10%,<90%"]
      |===
      |column A |column B
      |===
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/table/colgroup/col', output, 2
      assert_xpath '(/table/colgroup/col)[1][@style="width: 10%;"]', output, 1
      assert_xpath '(/table/colgroup/col)[2][@style="width: 90%;"]', output, 1
    end

    test 'spans, alignments and styles' do
      input = <<~'EOS'
      [cols="e,m,^,>s",width="25%"]
      |===
      |1 >s|2 |3 |4
      ^|5 2.2+^.^|6 .3+<.>m|7
      ^|8
      d|9 2+>|10
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 25%"]', output, 4
      assert_css 'table > tbody > tr', output, 4
      assert_css 'table > tbody > tr > td', output, 10
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 1
      assert_css 'table > tbody > tr:nth-child(4) > td', output, 2

      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(1).halign-left.valign-top p em', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(2).halign-right.valign-top p strong', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(3).halign-center.valign-top p', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(3).halign-center.valign-top p *', output, 0
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(4).halign-right.valign-top p strong', output, 1

      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(1).halign-center.valign-top p em', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(2).halign-center.valign-middle[colspan="2"][rowspan="2"] p code', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(3).halign-left.valign-bottom[rowspan="3"] p code', output, 1

      assert_css 'table > tbody > tr:nth-child(3) > td:nth-child(1).halign-center.valign-top p em', output, 1

      assert_css 'table > tbody > tr:nth-child(4) > td:nth-child(1).halign-left.valign-top p', output, 1
      assert_css 'table > tbody > tr:nth-child(4) > td:nth-child(1).halign-left.valign-top p em', output, 0
      assert_css 'table > tbody > tr:nth-child(4) > td:nth-child(2).halign-right.valign-top[colspan="2"] p code', output, 1
    end

    test 'sets up columns correctly if first row has cell that spans columns' do
      input = <<~'EOS'
      |===
      2+^|AAA |CCC
      |AAA |BBB |CCC
      |AAA |BBB |CCC
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(1)[colspan="2"]', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(2):not([colspan])', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:not([colspan])', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td:not([colspan])', output, 3
    end

    test 'supports repeating cells' do
      input = <<~'EOS'
      |===
      3*|A
      |1 3*|2
      |b |c
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 3

      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p[text()="A"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[3]/p[text()="A"]', output, 1

      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="1"]', output, 1
      assert_xpath '/table/tbody/tr[2]/td[2]/p[text()="2"]', output, 1
      assert_xpath '/table/tbody/tr[2]/td[3]/p[text()="2"]', output, 1

      assert_xpath '/table/tbody/tr[3]/td[1]/p[text()="2"]', output, 1
      assert_xpath '/table/tbody/tr[3]/td[2]/p[text()="b"]', output, 1
      assert_xpath '/table/tbody/tr[3]/td[3]/p[text()="c"]', output, 1
    end

    test 'calculates colnames correctly when using implicit column count and single cell with colspan' do
      input = <<~'EOS'
      |===
      2+|Two Columns
      |One Column |One Column
      |===
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '//colspec', output, 2
      assert_xpath '(//colspec)[1][@colname="col_1"]', output, 1
      assert_xpath '(//colspec)[2][@colname="col_2"]', output, 1
      assert_xpath '//row', output, 2
      assert_xpath '(//row)[1]/entry', output, 1
      assert_xpath '(//row)[1]/entry[@namest="col_1"][@nameend="col_2"]', output, 1
    end

    test 'calculates colnames correctly when using implicit column count and cells with mixed colspans' do
      input = <<~'EOS'
      |===
      2+|Two Columns | One Column
      |One Column |One Column |One Column
      |===
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '//colspec', output, 3
      assert_xpath '(//colspec)[1][@colname="col_1"]', output, 1
      assert_xpath '(//colspec)[2][@colname="col_2"]', output, 1
      assert_xpath '(//colspec)[3][@colname="col_3"]', output, 1
      assert_xpath '//row', output, 2
      assert_xpath '(//row)[1]/entry', output, 2
      assert_xpath '(//row)[1]/entry[@namest="col_1"][@nameend="col_2"]', output, 1
      assert_xpath '(//row)[2]/entry[@namest]', output, 0
      assert_xpath '(//row)[2]/entry[@nameend]', output, 0
    end

    test 'assigns unique column names for table with implicit column count and colspans in first row' do
      input = <<~'EOS'
      |===
      |                 2+| Node 0          2+| Node 1

      | Host processes    | Core 0 | Core 1   | Core 4 | Core 5
      | Guest processes   | Core 2 | Core 3   | Core 6 | Core 7
      |===
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '//colspec', output, 5
      (1..5).each do |n|
        assert_xpath %((//colspec)[#{n}][@colname="col_#{n}"]), output, 1
      end
      assert_xpath '(//row)[1]/entry', output, 3
      assert_xpath '((//row)[1]/entry)[1][@namest]', output, 0
      assert_xpath '((//row)[1]/entry)[1][@namend]', output, 0
      assert_xpath '((//row)[1]/entry)[2][@namest="col_2"][@nameend="col_3"]', output, 1
      assert_xpath '((//row)[1]/entry)[3][@namest="col_4"][@nameend="col_5"]', output, 1
    end

    test 'should drop row but preserve remaining rows after cell with colspan exceeds number of columns' do
      input = <<~'EOS'
      [cols=2*]
      |===
      3+|A
      |B
      a|C

      more C
      |===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table tr', output, 1
        assert_xpath '/table/tbody/tr/td[1]/p[text()="B"]', output, 1
        assert_message logger, :ERROR, '<stdin>: line 3: dropping cell because it exceeds specified number of columns', Hash
      end
    end

    test 'should drop last row if last cell in table has colspan that exceeds specified number of columns' do
      input = <<~'EOS'
      [cols=2*]
      |===
      |a 2+|b
      |===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table *', output, 0
        assert_message logger, :ERROR, '<stdin>: line 3: dropping cell because it exceeds specified number of columns', Hash
      end
    end

    test 'should drop last row if last cell in table has colspan that exceeds implicit number of columns' do
      input = <<~'EOS'
      |===
      |a |b
      |c 2+|d
      |===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table tr', output, 1
        assert_xpath '/table/tbody/tr/td[1]/p[text()="a"]', output, 1
        assert_message logger, :ERROR, '<stdin>: line 3: dropping cell because it exceeds specified number of columns', Hash
      end
    end

    test 'should take colspan into account when taking cells for row' do
      input = <<~'EOS'
      [cols=7]
      |===
      2+|a 2+|b 2+|c 2+|d
      |e |f |g |h |i |j |k
      |===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table tr', output, 1
        assert_css 'table tr td', output, 7
        assert_message logger, :ERROR, '<stdin>: line 3: dropping cell because it exceeds specified number of columns', Hash
      end
    end

    test 'should drop incomplete row at end of table and log an error' do
      input = <<~'EOS'
      [cols=2*]
      |===
      |a |b
      |c |d
      |e
      |===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table tr', output, 2
        assert_message logger, :ERROR, '<stdin>: line 5: dropping cells from incomplete row detected end of table', Hash
      end
    end

    test 'should apply cell style for column to repeated content' do
      input = <<~'EOS'
      [cols=",^l"]
      |===
      |Paragraphs |Literal

      2*|The discussion about what is good,
      what is beautiful, what is noble,
      what is pure, and what is true
      could always go on.

      Why is that important?
      Why would I like to do that?

      Because that's the only conversation worth having.

      And whether it goes on or not after I die, I don't know.
      But, I do know that it is the conversation I want to have while I am still alive.

      Which means that to me the offer of certainty,
      the offer of complete security,
      the offer of an impermeable faith that can't give way
      is an offer of something not worth having.

      I want to live my life taking the risk all the time
      that I don't know anything like enough yet...
      that I haven't understood enough...
      that I can't know enough...
      that I am always hungrily operating on the margins
      of a potentially great harvest of future knowledge and wisdom.

      I wouldn't have it any other way.
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr > td', output, 2
      assert_css 'table > tbody > tr > td:nth-child(1).halign-left.valign-top > p.tableblock', output, 7
      assert_css 'table > tbody > tr > td:nth-child(2).halign-center.valign-top > div.literal > pre', output, 1
      literal = xmlnodes_at_css 'table > tbody > tr > td:nth-child(2).halign-center.valign-top > div.literal > pre', output, 1
      assert_equal 26, literal.text.lines.size
    end

    test 'should not split paragraph at line containing only {blank} that is directly adjacent to non-blank lines' do
      input = <<~'EOS'
      |===
      |paragraph
      {blank}
      still one paragraph
      {blank}
      still one paragraph
      |===
      EOS

      result = convert_string_to_embedded input
      assert_css 'p.tableblock', result, 1
    end

    test 'should strip trailing newlines when splitting paragraphs' do
      input = <<~'EOS'
      |===
      |first wrapped
      paragraph

      second paragraph

      third paragraph
      |===
      EOS

      result = convert_string_to_embedded input
      assert_xpath %((//p[@class="tableblock"])[1][text()="first wrapped\nparagraph"]), result, 1
      assert_xpath %((//p[@class="tableblock"])[2][text()="second paragraph"]), result, 1
      assert_xpath %((//p[@class="tableblock"])[3][text()="third paragraph"]), result, 1
    end

    test 'basic AsciiDoc cell' do
      input = <<~'EOS'
      |===
      a|--
      NOTE: content

      content
      --
      |===
      EOS

      result = convert_string_to_embedded input
      assert_css 'table.tableblock', result, 1
      assert_css 'table.tableblock td.tableblock', result, 1
      assert_css 'table.tableblock td.tableblock .openblock', result, 1
      assert_css 'table.tableblock td.tableblock .openblock .admonitionblock', result, 1
      assert_css 'table.tableblock td.tableblock .openblock .paragraph', result, 1
    end

    test 'AsciiDoc table cell should be wrapped in div with class "content"' do
      input = <<~'EOS'
      |===
      a|AsciiDoc table cell
      |===
      EOS

      result = convert_string_to_embedded input
      assert_css 'table.tableblock td.tableblock > div.content', result, 1
      assert_css 'table.tableblock td.tableblock > div.content > div.paragraph', result, 1
    end

    test 'doctype can be set in AsciiDoc table cell' do
      input = <<~'EOS'
      |===
      a|
      :doctype: inline

      content
      |===
      EOS

      result = convert_string_to_embedded input
      assert_css 'table.tableblock', result, 1
      assert_css 'table.tableblock .paragraph', result, 0
    end

    test 'should reset doctype to default in AsciiDoc table cell' do
      input = <<~'EOS'
      = Book Title
      :doctype: book

      == Chapter 1

      |===
      a|
      = AsciiDoc Table Cell

      doctype={doctype}
      {backend-html5-doctype-article}
      {backend-html5-doctype-book}
      |===
      EOS

      result = convert_string_to_embedded input, attributes: { 'attribute-missing' => 'skip' }
      assert_includes result, 'doctype=article'
      refute_includes result, '{backend-html5-doctype-article}'
      assert_includes result, '{backend-html5-doctype-book}'
    end

    test 'should update doctype-related attributes in AsciiDoc table cell when doctype is set' do
      input = <<~'EOS'
      = Document Title
      :doctype: article

      == Chapter 1

      |===
      a|
      = AsciiDoc Table Cell
      :doctype: book

      doctype={doctype}
      {backend-html5-doctype-book}
      {backend-html5-doctype-article}
      |===
      EOS

      result = convert_string_to_embedded input, attributes: { 'attribute-missing' => 'skip' }
      assert_includes result, 'doctype=book'
      refute_includes result, '{backend-html5-doctype-book}'
      assert_includes result, '{backend-html5-doctype-article}'
    end

    test 'should not allow AsciiDoc table cell to set a document attribute that was hard set by the API' do
      input = <<~'EOS'
      |===
      a|
      :icons:

      NOTE: This admonition does not have a font-based icon.
      |===
      EOS

      result = convert_string_to_embedded input, safe: :safe, attributes: { 'icons' => 'font' }
      assert_css 'td.icon .title', result, 0
      assert_css 'td.icon i.icon-note', result, 1
    end

    test 'should not allow AsciiDoc table cell to set a document attribute that was hard unset by the API' do
      input = <<~'EOS'
      |===
      a|
      :icons: font

      NOTE: This admonition does not have a font-based icon.
      |===
      EOS

      result = convert_string_to_embedded input, safe: :safe, attributes: { 'icons' => nil }
      assert_css 'td.icon .title', result, 1
      assert_css 'td.icon i.icon-note', result, 0
      assert_xpath '//td[@class="icon"]/*[@class="title"][text()="Note"]', result, 1
    end

    test 'should keep attribute unset in AsciiDoc table cell if unset in parent document' do
      input = <<~'EOS'
      :!sectids:
      :!table-caption:

      == Outer Heading

      .Outer Table
      |===
      a|

      == Inner Heading

      .Inner Table
      !===
      ! table cell
      !===
      |===
      EOS

      result = convert_string_to_embedded input
      assert_xpath 'h2[id]', result, 0
      assert_xpath '//caption[text()="Outer Table"]', result, 1
      assert_xpath '//caption[text()="Inner Table"]', result, 1
    end

    test 'should allow attribute unset in parent document to be set in AsciiDoc table cell' do
      input = <<~'EOS'
      :!sectids:

      == No ID

      |===
      a|

      == No ID

      :sectids:

      == Has ID
      |===
      EOS

      result = convert_string_to_embedded input
      headings = xmlnodes_at_css 'h2', result
      assert_equal 3, headings.size
      assert_nil headings[0].attr :id
      assert_nil headings[1].attr :id
      assert_equal '_has_id', (headings[2].attr :id)
    end

    test 'should not allow locked attribute unset in parent document to be set in AsciiDoc table cell' do
      input = <<~'EOS'
      == No ID

      |===
      a|

      == No ID

      :sectids:

      == Has ID
      |===
      EOS

      result = convert_string_to_embedded input, attributes: { 'sectids' => nil }
      headings = xmlnodes_at_css 'h2', result
      assert_equal 3, headings.size
      headings.each {|heading| assert_nil heading.attr :id }
    end

    test 'showtitle can be enabled in AsciiDoc table cell if unset in parent document' do
      %w(showtitle notitle).each do |name|
        input = <<~EOS
        = Document Title
        :#{name == 'showtitle' ? '!' : ''}#{name}:

        |===
        a|
        = Nested Document Title
        :#{name == 'showtitle' ? '' : '!'}#{name}:

        content
        |===
        EOS

        result = convert_string_to_embedded input
        assert_css 'h1', result, 1
        assert_css '.tableblock h1', result, 1
      end
    end

    test 'showtitle can be enabled in AsciiDoc table cell if unset by API' do
      %w(showtitle notitle).each do |name|
        input = <<~EOS
        = Document Title

        |===
        a|
        = Nested Document Title
        :#{name == 'showtitle' ? '' : '!'}#{name}:

        content
        |===
        EOS

        result = convert_string_to_embedded input, attributes: { name => (name == 'showtitle' ? nil : '') }
        assert_css 'h1', result, 1
        assert_css '.tableblock h1', result, 1
      end
    end

    test 'showtitle can be disabled in AsciiDoc table cell if set in parent document' do
      %w(showtitle notitle).each do |name|
        input = <<~EOS
        = Document Title
        :#{name == 'showtitle' ? '' : '!'}#{name}:

        |===
        a|
        = Nested Document Title
        :#{name == 'showtitle' ? '!' : ''}#{name}:

        content
        |===
        EOS

        result = convert_string_to_embedded input
        assert_css 'h1', result, 1
        assert_css '.tableblock h1', result, 0
      end
    end

    test 'showtitle can be disabled in AsciiDoc table cell if set by API' do
      %w(showtitle notitle).each do |name|
        input = <<~EOS
        = Document Title

        |===
        a|
        = Nested Document Title
        :#{name == 'showtitle' ? '!' : ''}#{name}:

        content
        |===
        EOS

        result = convert_string_to_embedded input, attributes: { name => (name == 'showtitle' ? '' : nil) }
        assert_css 'h1', result, 1
        assert_css '.tableblock h1', result, 0
      end
    end

    test 'AsciiDoc content' do
      input = <<~'EOS'
      [cols="1e,1,5a"]
      |===
      |Name |Backends |Description

      |badges |xhtml11, html5 |
      Link badges ('XHTML 1.1' and 'CSS') in document footers.

      [NOTE]
      ====
      The path names of images, icons and scripts are relative path
      names to the output document not the source document.
      ====
      |[[X97]] docinfo, docinfo1, docinfo2 |All backends |
      These three attributes control which document information
      files will be included in the the header of the output file:

      docinfo:: Include `<filename>-docinfo.<ext>`
      docinfo1:: Include `docinfo.<ext>`
      docinfo2:: Include `docinfo.<ext>` and `<filename>-docinfo.<ext>`

      Where `<filename>` is the file name (sans extension) of the AsciiDoc
      input file and `<ext>` is `.html` for HTML outputs or `.xml` for
      DocBook outputs. If the input file is the standard input then the
      output file name is used.
      |===
      EOS
      doc = document_from_string input, sourcemap: true
      table = doc.blocks.first
      refute_nil table
      tbody = table.rows.body
      assert_equal 2, tbody.size
      body_cell_1_2 = tbody[0][1]
      assert_equal 5, body_cell_1_2.lineno
      body_cell_1_3 = tbody[0][2]
      refute_nil body_cell_1_3.inner_document
      assert body_cell_1_3.inner_document.nested?
      assert_equal doc, body_cell_1_3.inner_document.parent_document
      assert_equal doc.converter, body_cell_1_3.inner_document.converter
      assert_equal 5, body_cell_1_3.lineno
      assert_equal 6, body_cell_1_3.inner_document.lineno
      note = (body_cell_1_3.inner_document.find_by context: :admonition)[0]
      assert_equal 9, note.lineno
      output = doc.convert standalone: false

      # NOTE JRuby matches the table inside the admonition block if the class is not specified on the table
      assert_css 'table.tableblock > tbody > tr', output, 2
      assert_css 'table.tableblock > tbody > tr:nth-child(1) > td:nth-child(3) div.admonitionblock', output, 1
      assert_css 'table.tableblock > tbody > tr:nth-child(2) > td:nth-child(3) div.dlist', output, 1
    end

    test 'should preserve leading indentation in contents of AsciiDoc table cell if contents starts with newline' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      |===
      a|
       $ command
      a| paragraph
      |===
      EOS
      doc = document_from_string input, sourcemap: true
      table = doc.blocks[0]
      tbody = table.rows.body
      assert_equal 1, table.lineno
      assert_equal 2, tbody[0][0].lineno
      assert_equal 3, tbody[0][0].inner_document.lineno
      assert_equal 4, tbody[1][0].lineno
      output = doc.convert standalone: false
      assert_css 'td', output, 2
      assert_xpath '(//td)[1]//*[@class="literalblock"]', output, 1
      assert_xpath '(//td)[2]//*[@class="paragraph"]', output, 1
      assert_xpath '(//pre)[1][text()="$ command"]', output, 1
      assert_xpath '(//p)[1][text()="paragraph"]', output, 1
    end

    test 'preprocessor directive on first line of an AsciiDoc table cell should be processed' do
      input = <<~'EOS'
      |===
      a|include::fixtures/include-file.adoc[]
      |===
      EOS

      output = convert_string_to_embedded input, safe: :safe, base_dir: testdir
      assert_match(/included content/, output)
    end

    test 'error about unresolved preprocessor directive on first line of an AsciiDoc table cell should have correct cursor' do
      begin
        tmp_include = Tempfile.new %w(include- .adoc)
        tmp_include_dir, tmp_include_path = File.split tmp_include.path
        tmp_include.write <<~'EOS'
        |===
        |A |B

        |text
        a|include::does-not-exist.adoc[]
        |===
        EOS
        tmp_include.close
        input = <<~EOS
        first

        include::#{tmp_include_path}[]

        last
        EOS
        using_memory_logger do |logger|
          output = convert_string_to_embedded input, safe: :safe, base_dir: tmp_include_dir
          assert_includes output, %(Unresolved directive in #{tmp_include_path})
          assert_message logger, :ERROR, %(#{tmp_include_path}: line 5: include file not found: #{File.join tmp_include_dir, 'does-not-exist.adoc'}), Hash
        end
      ensure
        tmp_include.close!
      end
    end

    test 'cross reference link in an AsciiDoc table cell should resolve to reference in main document' do
      input = <<~'EOS'
      == Some

      |===
      a|See <<_more>>
      |===

      == More

      content
      EOS

      result = convert_string input
      assert_xpath '//a[@href="#_more"]', result, 1
      assert_xpath '//a[@href="#_more"][text()="More"]', result, 1
    end

    test 'should discover anchor at start of cell and register it as a reference' do
      input = <<~'EOS'
      The highest peak in the Front Range is <<grays-peak>>, which tops <<mount-evans>> by just a few feet.

      [cols="1s,1"]
      |===
      |[[mount-evans,Mount Evans]]Mount Evans
      |14,271 feet

      h|[[grays-peak,Grays Peak]]
      Grays Peak
      |14,278 feet
      |===
      EOS
      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('mount-evans')
      assert refs.key?('grays-peak')
      output = doc.convert standalone: false
      assert_xpath '(//p)[1]/a[@href="#grays-peak"][text()="Grays Peak"]', output, 1
      assert_xpath '(//p)[1]/a[@href="#mount-evans"][text()="Mount Evans"]', output, 1
      assert_xpath '(//table/tbody/tr)[1]//td//a[@id="mount-evans"]', output, 1
      assert_xpath '(//table/tbody/tr)[2]//th//a[@id="grays-peak"]', output, 1
    end

    test 'should catalog anchor at start of cell in implicit header row when column has a style' do
      input = <<~'EOS'
      [cols=1a]
      |===
      |[[foo,Foo]]* not AsciiDoc

      | AsciiDoc
      |===
      EOS
      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('foo')
    end

    test 'should catalog anchor at start of cell in explicit header row when column has a style' do
      input = <<~'EOS'
      [%header,cols=1a]
      |===
      |[[foo,Foo]]* not AsciiDoc
      | AsciiDoc
      |===
      EOS
      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('foo')
    end

    test 'should catalog anchor at start of cell in first row' do
      input = <<~'EOS'
      |===
      |[[foo,Foo]]foo
      | bar
      |===
      EOS
      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('foo')
    end

    test 'footnotes should not be shared between an AsciiDoc table cell and the main document' do
      input = <<~'EOS'
      |===
      a|AsciiDoc footnote:[A lightweight markup language.]
      |===
      EOS

      result = convert_string input
      assert_css '#_footnotedef_1', result, 1
    end

    test 'callout numbers should be globally unique, including AsciiDoc table cells' do
      input = <<~'EOS'
      = Document Title

      == Section 1

      |===
      a|
      [source, yaml]
      ----
      key: value <1>
      ----
      <1> First callout
      |===

      == Section 2

      |===
      a|
      [source, yaml]
      ----
      key: value <1>
      ----
      <1> Second callout
      |===

      == Section 3

      [source, yaml]
      ----
      key: value <1>
      ----
      <1> Third callout
      EOS

      result = convert_string_to_embedded input, backend: 'docbook'
      conums = xmlnodes_at_xpath '//co', result
      assert_equal 3, conums.size
      ['CO1-1', 'CO2-1', 'CO3-1'].each_with_index do |conum, idx|
        assert_equal conum, conums[idx].attribute('xml:id').value
      end
      callouts = xmlnodes_at_xpath '//callout', result
      assert_equal 3, callouts.size
      ['CO1-1', 'CO2-1', 'CO3-1'].each_with_index do |callout, idx|
        assert_equal callout, callouts[idx].attribute('arearefs').value
      end
    end

    test 'compat mode can be activated in AsciiDoc table cell' do
      input = <<~'EOS'
      |===
      a|
      :compat-mode:

      The word 'italic' is emphasized.
      |===
      EOS

      result = convert_string_to_embedded input
      assert_xpath '//em[text()="italic"]', result, 1
    end

    test 'compat mode in AsciiDoc table cell inherits from parent document' do
      input = <<~'EOS'
      :compat-mode:

      The word 'italic' is emphasized.

      [cols=1*]
      |===
      |The word 'oblique' is emphasized.
      a|
      The word 'slanted' is emphasized.
      |===

      The word 'askew' is emphasized.
      EOS

      result = convert_string_to_embedded input
      assert_xpath '//em[text()="italic"]', result, 1
      assert_xpath '//em[text()="oblique"]', result, 1
      assert_xpath '//em[text()="slanted"]', result, 1
      assert_xpath '//em[text()="askew"]', result, 1
    end

    test 'compat mode in AsciiDoc table cell can be unset if set in parent document' do
      input = <<~'EOS'
      :compat-mode:

      The word 'italic' is emphasized.

      [cols=1*]
      |===
      |The word 'oblique' is emphasized.
      a|
      :!compat-mode:

      The word 'slanted' is not emphasized.
      |===

      The word 'askew' is emphasized.
      EOS

      result = convert_string_to_embedded input
      assert_xpath '//em[text()="italic"]', result, 1
      assert_xpath '//em[text()="oblique"]', result, 1
      assert_xpath '//em[text()="slanted"]', result, 0
      assert_xpath '//em[text()="askew"]', result, 1
    end

    test 'nested table' do
      input = <<~'EOS'
      [cols="1,2a"]
      |===
      |Normal cell
      |Cell with nested table
      [cols="2,1"]
      !===
      !Nested table cell 1 !Nested table cell 2
      !===
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 2
      assert_css 'table table', output, 1
      assert_css 'table > tbody > tr > td:nth-child(2) table', output, 1
      assert_css 'table > tbody > tr > td:nth-child(2) table > tbody > tr > td', output, 2
    end

    test 'can set format of nested table to psv' do
      input = <<~'EOS'
      [cols="2*"]
      |===
      |normal cell
      a|
      [format=psv]
      !===
      !nested cell
      !===
      |===
      EOS

      output = convert_string_to_embedded input
      assert_css 'table', output, 2
      assert_css 'table table', output, 1
      assert_css 'table > tbody > tr > td:nth-child(2) table', output, 1
      assert_css 'table > tbody > tr > td:nth-child(2) table > tbody > tr > td', output, 1
    end

    test 'AsciiDoc table cell should inherit to_dir option from parent document' do
      doc = document_from_string <<~'EOS', parse: true, to_dir: testdir
      |===
      a|
      AsciiDoc table cell
      |===
      EOS

      nested_doc = (doc.blocks[0].find_by context: :document, traverse_documents: true)[0]
      assert nested_doc.nested?
      assert_equal doc.options[:to_dir], nested_doc.options[:to_dir]
    end

    test 'AsciiDoc table cell should not inherit toc setting from parent document' do
      input = <<~'EOS'
      = Document Title
      :toc:

      == Section

      |===
      a|
      == Section in Nested Document

      content
      |===
      EOS

      output = convert_string input
      assert_css '.toc', output, 1
      assert_css 'table .toc', output, 0
    end

    test 'should be able to enable toc in an AsciiDoc table cell' do
      input = <<~'EOS'
      = Document Title

      == Section A

      |===
      a|
      = Subdocument Title
      :toc:

      == Subdocument Section A

      content
      |===
      EOS

      output = convert_string input
      assert_css '.toc', output, 1
      assert_css 'table .toc', output, 1
    end

    test 'should be able to enable toc in an AsciiDoc table cell even if hard unset by API' do
      input = <<~'EOS'
      = Document Title

      == Section A

      |===
      a|
      = Subdocument Title
      :toc:

      == Subdocument Section A

      content
      |===
      EOS

      output = convert_string input, attributes: { 'toc' => nil }
      assert_css '.toc', output, 1
      assert_css 'table .toc', output, 1
    end

    test 'should be able to enable toc in both outer document and in an AsciiDoc table cell' do
      input = <<~'EOS'
      = Document Title
      :toc:

      == Section A

      |===
      a|
      = Subdocument Title
      :toc: macro

      [#table-cell-toc]
      toc::[]

      == Subdocument Section A

      content
      |===
      EOS

      output = convert_string input
      assert_css '.toc', output, 2
      assert_css '#toc', output, 1
      assert_css 'table .toc', output, 1
      assert_css 'table #table-cell-toc', output, 1
    end

    test 'document in an AsciiDoc table cell should not see doctitle of parent' do
      input = <<~'EOS'
      = Document Title

      [cols="1a"]
      |===
      |AsciiDoc content
      |===
      EOS

      output = convert_string input
      assert_css 'table', output, 1
      assert_css 'table > tbody > tr > td', output, 1
      assert_css 'table > tbody > tr > td #preamble', output, 0
      assert_css 'table > tbody > tr > td .paragraph', output, 1
    end

    test 'cell background color' do
      input = <<~'EOS'
      [cols="1e,1", options="header"]
      |===
      |{set:cellbgcolor:green}green
      |{set:cellbgcolor!}
      plain
      |{set:cellbgcolor:red}red
      |{set:cellbgcolor!}
      plain
      |===
      EOS

      output = convert_string_to_embedded input
      assert_xpath '(/table/thead/tr/th)[1][@style="background-color: green;"]', output, 1
      assert_xpath '(/table/thead/tr/th)[2][@style="background-color: green;"]', output, 0
      assert_xpath '(/table/tbody/tr/td)[1][@style="background-color: red;"]', output, 1
      assert_xpath '(/table/tbody/tr/td)[2][@style="background-color: green;"]', output, 0
    end

    test 'should warn if table block is not terminated' do
      input = <<~'EOS'
      outside

      |===
      |
      inside

      still inside

      eof
      EOS

      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_xpath '/table', output, 1
        assert_message logger, :WARN, '<stdin>: line 3: unterminated table block', Hash
      end
    end

    test 'should show correct line number in warning about unterminated block inside AsciiDoc table cell' do
      input = <<~'EOS'
      outside

      * list item
      +
      |===
      |cell
      a|inside

      ====
      unterminated example block
      |===

      eof
      EOS

      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_xpath '//ul//table', output, 1
        assert_message logger, :WARN, '<stdin>: line 9: unterminated example block', Hash
      end
    end

    test 'custom separator for an AsciiDoc table cell' do
      input = <<~'EOS'
      [cols=2,separator=!]
      |===
      !Pipe output to vim
      a!
      ----
      asciidoctor -o - -s test.adoc | view -
      ----
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(1) p', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(2) .listingblock', output, 1
    end

    test 'table with breakable option docbook 5' do
      input = <<~'EOS'
      .Table with breakable
      [%breakable]
      |===
      |Item       |Quantity
      |Item 1     |1
      |===
      EOS
      output = convert_string_to_embedded input, backend: 'docbook5'
      assert_includes output, '<?dbfo keep-together="auto"?>'
    end

    test 'table with unbreakable option docbook 5' do
      input = <<~'EOS'
      .Table with unbreakable
      [%unbreakable]
      |===
      |Item       |Quantity
      |Item 1     |1
      |===
      EOS
      output = convert_string_to_embedded input, backend: 'docbook5'
      assert_includes output, '<?dbfo keep-together="always"?>'
    end

    test 'no implicit header row if cell in first line is quoted and spans multiple lines' do
      input = <<~'EOS'
      [cols=2*l]
      ,===
      "A1

      A1 continued",B1
      A2,B2
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 2
      assert_xpath %((//td)[1]//pre[text()="A1\n\nA1 continued"]), output, 1
    end
  end

  context 'DSV' do
    test 'converts simple dsv table' do
      input = <<~'EOS'
      [width="75%",format="dsv"]
      |===
      root:x:0:0:root:/root:/bin/bash
      bin:x:1:1:bin:/bin:/sbin/nologin
      mysql:x:27:27:MySQL\:Server:/var/lib/mysql:/bin/bash
      gdm:x:42:42::/var/lib/gdm:/sbin/nologin
      sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin
      nobody:x:99:99:Nobody:/:/sbin/nologin
      |===
      EOS
      doc = document_from_string input, standalone: false
      table = doc.blocks[0]
      assert_equal 100, table.columns.map {|col| col.attributes['colpcwidth'] }.reduce(:+)
      output = doc.convert
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 14.2857%"]', output, 6
      assert_css 'table > colgroup > col:last-of-type[style*="width: 14.2858%"]', output, 1
      assert_css 'table > tbody > tr', output, 6
      assert_xpath '//tr[4]/td[5]/p/text()', output, 0
      assert_xpath '//tr[3]/td[5]/p[text()="MySQL:Server"]', output, 1
    end

    test 'dsv format shorthand' do
      input = <<~'EOS'
      :===
      a:b:c
      1:2:3
      :===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'single cell in DSV table should only produce single row' do
      input = <<~'EOS'
      :===
      single cell
      :===
      EOS

      output = convert_string_to_embedded input
      assert_css 'table td', output, 1
    end

    test 'should treat trailing colon as an empty cell' do
      input = <<~'EOS'
      :===
      A1:
      B1:B2
      C1:C2
      :===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A1"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 0
      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="B1"]', output, 1
    end
  end

  context 'CSV' do
    test 'should treat trailing comma as an empty cell' do
      input = <<~'EOS'
      ,===
      A1,
      B1,B2
      C1,C2
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A1"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 0
      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="B1"]', output, 1
    end

    test 'should log error but not crash if cell data has unclosed quote' do
      input = <<~'EOS'
      ,===
      a,b
      c,"
      ,===
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css 'table', output, 1
        assert_css 'table td', output, 4
        assert_xpath '(/table/td)[4]/p', output, 0
        assert_message logger, :ERROR, '<stdin>: line 3: unclosed quote in CSV data; setting cell to empty', Hash
      end
    end

    test 'should preserve newlines in quoted CSV values' do
      input = <<~'EOS'
      [cols="1,1,1l"]
      ,===
      "A
      B
      C","one

      two

      three","do

      re

      me"
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 1
      assert_xpath '/table/tbody/tr[1]/td', output, 3
      assert_xpath %(/table/tbody/tr[1]/td[1]/p[text()="A\nB\nC"]), output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 3
      assert_xpath '/table/tbody/tr[1]/td[2]/p[1][text()="one"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p[2][text()="two"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p[3][text()="three"]', output, 1
      assert_xpath %(/table/tbody/tr[1]/td[3]//pre[text()="do\n\nre\n\nme"]), output, 1
    end

    test 'should not drop trailing empty cell in TSV data when loaded from an include file' do
      input  = <<~'EOS'
      [%header,format=tsv]
      |===
      include::fixtures/data.tsv[]
      |===
      EOS
      output = convert_string_to_embedded input, safe: :safe, base_dir: ASCIIDOCTOR_TEST_DIR
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(3):empty', output, 1
    end

    test 'mixed unquoted records and quoted records with escaped quotes, commas, and wrapped lines' do
      input = <<~'EOS'
      [format="csv",options="header"]
      |===
      Year,Make,Model,Description,Price
      1997,Ford,E350,"ac, abs, moon",3000.00
      1999,Chevy,"Venture ""Extended Edition""","",4900.00
      1999,Chevy,"Venture ""Extended Edition, Very Large""",,5000.00
      1996,Jeep,Grand Cherokee,"MUST SELL!
      air, moon roof, loaded",4799.00
      2000,Toyota,Tundra,"""This one's gonna to blow you're socks off,"" per the sticker",10000.00
      2000,Toyota,Tundra,"Check it, ""this one's gonna to blow you're socks off"", per the sticker",10000.00
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 20%"]', output, 5
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > tbody > tr', output, 6
      assert_xpath '((//tbody/tr)[1]/td)[4]/p[text()="ac, abs, moon"]', output, 1
      assert_xpath %(((//tbody/tr)[2]/td)[3]/p[text()='Venture "Extended Edition"']), output, 1
      assert_xpath %(((//tbody/tr)[4]/td)[4]/p[text()="MUST SELL!\nair, moon roof, loaded"]), output, 1
      assert_xpath %(((//tbody/tr)[5]/td)[4]/p[text()='"This one#{decode_char 8217}s gonna to blow you#{decode_char 8217}re socks off," per the sticker']), output, 1
      assert_xpath %(((//tbody/tr)[6]/td)[4]/p[text()='Check it, "this one#{decode_char 8217}s gonna to blow you#{decode_char 8217}re socks off", per the sticker']), output, 1
    end

    test 'should allow quotes around a CSV value to be on their own lines' do
      input = <<~'EOS'
      [cols=2*]
      ,===
      "
      A
      ","
      B
      "
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 1
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p[text()="B"]', output, 1
    end

    test 'csv format shorthand' do
      input = <<~'EOS'
      ,===
      a,b,c
      1,2,3
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'tsv as format' do
      input = <<~EOS
      [format=tsv]
      ,===
      a\tb\tc
      1\t2\t3
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'custom csv separator' do
      input = <<~'EOS'
      [format=csv,separator=;]
      |===
      a;b;c
      1;2;3
      |===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'tab as separator' do
      input = <<~EOS
      [separator=\\t]
      ,===
      a\tb\tc
      1\t2\t3
      ,===
      EOS
      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'single cell in CSV table should only produce single row' do
      input = <<~'EOS'
      ,===
      single cell
      ,===
      EOS

      output = convert_string_to_embedded input
      assert_css 'table td', output, 1
    end

    test 'cell formatted with AsciiDoc style' do
      input = <<~'EOS'
      [cols="1,1,1a",separator=;]
      ,===
      element;description;example

      thematic break,a visible break; also known as a horizontal rule;---
      ,===
      EOS

      output = convert_string_to_embedded input
      assert_css 'table tbody hr', output, 1
    end

    test 'should strip whitespace around contents of AsciiDoc cell' do
      input = <<~'EOS'
      [cols="1,1,1a",separator=;]
      ,===
      element;description;example

      paragraph;contiguous lines of words and phrases;"
        one sentence, one line
        "
      ,===
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/table/tbody//*[@class="paragraph"]/p[text()="one sentence, one line"]', output, 1
    end
  end
end
