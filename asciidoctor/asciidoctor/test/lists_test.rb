# frozen_string_literal: true
require_relative 'test_helper'

context "Bulleted lists (:ulist)" do
  context "Simple lists" do
    test "dash elements with no blank lines" do
      input = <<~'EOS'
      List
      ====

      - Foo
      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented dash elements using spaces' do
      input = <<~EOS
      \x20- Foo
      \x20- Boo
      \x20- Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented dash elements using tabs' do
      input = <<~EOS
      \t-\tFoo
      \t-\tBoo
      \t-\tBlech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test "dash elements separated by blank lines should merge lists" do
      input = <<~'EOS'
      List
      ====

      - Foo

      - Boo


      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'dash elements with interspersed line comments should be skipped and not break list' do
      input = <<~'EOS'
      == List

      - Foo
      // line comment
      // another line comment
      - Boo
      // line comment
      more text
      // another line comment
      - Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath %((//ul/li)[2]/p[text()="Boo\nmore text"]), output, 1
    end

    test "dash elements separated by a line comment offset by blank lines should not merge lists" do
      input = <<~'EOS'
      List
      ====

      - Foo
      - Boo

      //

      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test "dash elements separated by a block title offset by a blank line should not merge lists" do
      input = <<~'EOS'
      List
      ====

      - Foo
      - Boo

      .Also
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
      assert_xpath '(//ul)[2]/preceding-sibling::*[@class = "title"][text() = "Also"]', output, 1
    end

    test "dash elements separated by an attribute entry offset by a blank line should not merge lists" do
      input = <<~'EOS'
      == List

      - Foo
      - Boo

      :foo: bar
      - Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test 'a non-indented wrapped line is folded into text of list item' do
      input = <<~'EOS'
      List
      ====

      - Foo
      wrapped content
      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\nwrapped content']", output, 1
    end

    test 'a non-indented wrapped line that resembles a block title is folded into text of list item' do
      input = <<~'EOS'
      == List

      - Foo
      .wrapped content
      - Boo
      - Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\n.wrapped content']", output, 1
    end

    test 'a non-indented wrapped line that resembles an attribute entry is folded into text of list item' do
      input = <<~'EOS'
      == List

      - Foo
      :foo: bar
      - Boo
      - Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\n:foo: bar']", output, 1
    end

    test 'a list item with a nested marker terminates non-indented paragraph for text of list item' do
      input = <<~'EOS'
      - Foo
      Bar
      * Foo
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul ul', output, 1
      refute_includes output, '* Foo'
    end

    test 'a list item for a different list terminates non-indented paragraph for text of list item' do
      input = <<~'EOS'
      == Example 1

      - Foo
      Bar
      . Foo

      == Example 2

      * Item
      text
      term:: def
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul ol', output, 1
      refute_includes output, '* Foo'
      assert_css 'ul dl', output, 1
      refute_includes output, 'term:: def'
    end

    test 'an indented wrapped line is unindented and folded into text of list item' do
      input = <<~'EOS'
      List
      ====

      - Foo
        wrapped content
      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath "//ul/li[1]/p[text() = 'Foo\nwrapped content']", output, 1
    end

    test 'wrapped list item with hanging indent followed by non-indented line' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      - list item 1
        // not line comment
      second wrapped line
      - list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css 'ul', output, 1
      assert_css 'ul li', output, 2
      # NOTE for some reason, we're getting an extra line after the indented line
      lines = xmlnodes_at_xpath('(//ul/li)[1]/p', output, 1).text.gsub(/\n[[:space:]]*\n/, ?\n).lines
      assert_equal 3, lines.size
      assert_equal 'list item 1', lines[0].chomp
      assert_equal '  // not line comment', lines[1].chomp
      assert_equal 'second wrapped line', lines[2].chomp
    end

    test 'a list item with a nested marker terminates indented paragraph for text of list item' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      - Foo
        Bar
      * Foo
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul ul', output, 1
      refute_includes output, '* Foo'
    end

    test 'a list item that starts with a sequence of list markers characters should not match a nested list' do
      input = <<~EOS
      \x20* first item
      \x20*. normal text
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul', output, 1
      assert_css 'ul li', output, 1
      assert_xpath "//ul/li/p[text()='first item\n*. normal text']", output, 1
    end

    test 'a list item for a different list terminates indented paragraph for text of list item' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Example 1

      - Foo
        Bar
      . Foo

      == Example 2

      * Item
        text
      term:: def
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul ol', output, 1
      refute_includes output, '* Foo'
      assert_css 'ul dl', output, 1
      refute_includes output, 'term:: def'
    end

    test "a literal paragraph offset by blank lines in list content is appended as a literal block" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      List
      ====

      - Foo

        literal

      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "literal"]', output, 1
    end

    test 'should escape special characters in all literal paragraphs attached to list item' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      * first item

        <code>text</code>

        more <code>text</code>

      * second item
      EOS

      output = convert_string_to_embedded input
      assert_css 'li', output, 2
      assert_css 'code', output, 0
      assert_css 'li:first-of-type > *', output, 3
      assert_css 'li:first-of-type pre', output, 2
      assert_xpath '((//li)[1]//pre)[1][text()="<code>text</code>"]', output, 1
      assert_xpath '((//li)[1]//pre)[2][text()="more <code>text</code>"]', output, 1
    end

    test "a literal paragraph offset by a blank line in list content followed by line with continuation is appended as two blocks" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      List
      ====

      - Foo

        literal
      +
      para

      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "literal"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'an admonition paragraph attached by a line continuation to a list item with wrapped text should produce admonition' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      - first-line text
        wrapped text
      +
      NOTE: This is a note.
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul', output, 1
      assert_css 'ul > li', output, 1
      assert_css 'ul > li > p', output, 1
      assert_xpath %(//ul/li/p[text()="first-line text\nwrapped text"]), output, 1
      assert_css 'ul > li > p + .admonitionblock.note', output, 1
      assert_xpath '//ul/li/*[@class="admonitionblock note"]//td[@class="content"][normalize-space(text())="This is a note."]', output, 1
    end

    test 'paragraph-like blocks attached to an ancestor list item by a list continuation should produce blocks' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      * parent
       ** child

      +
      NOTE: This is a note.

      * another parent
       ** another child

      +
      '''
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul ul .admonitionblock.note', output, 0
      assert_xpath '(//ul)[1]/li/*[@class="admonitionblock note"]', output, 1
      assert_css 'ul ul hr', output, 0
      assert_xpath '(//ul)[1]/li/hr', output, 1
    end

    test 'should not inherit block attributes from previous block when block is attached using a list continuation' do
      input = <<~'EOS'
      * complex list item
      +
      [source,xml]
      ----
      <name>value</name> <!--1-->
      ----
      <1> a configuration value
      EOS

      doc = document_from_string input
      colist = doc.blocks[0].items[0].blocks[-1]
      assert_equal :colist, colist.context
      refute_equal 'source', colist.style
      output = doc.convert standalone: false
      assert_css 'ul', output, 1
      assert_css 'ul > li', output, 1
      assert_css 'ul > li > p', output, 1
      assert_css 'ul > li > .listingblock', output, 1
      assert_css 'ul > li > .colist', output, 1
    end

    test 'should continue to parse blocks attached by a list continuation after block is dropped' do
      input = <<~'EOS'
      * item
      +
      paragraph
      +
      [comment]
      comment
      +
      ====
      example
      ====
      '''
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul > li > .paragraph', output, 1
      assert_css 'ul > li > .exampleblock', output, 1
    end

    test 'appends line as paragraph if attached by continuation following line comment' do
      input = <<~'EOS'
      - list item 1
      // line comment
      +
      paragraph in list item 1

      - list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css 'ul', output, 1
      assert_css 'ul li', output, 2
      assert_xpath '(//ul/li)[1]/p[text()="list item 1"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="paragraph"]/p[text()="paragraph in list item 1"]', output, 1
      assert_xpath '(//ul/li)[2]/p[text()="list item 2"]', output, 1
    end

    test "a literal paragraph with a line that appears as a list item that is followed by a continuation should create two blocks" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      * Foo
      +
        literal
      . still literal
      +
      para

      * Bar
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath %(((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text() = "  literal\n. still literal"]), output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test "consecutive literal paragraph offset by blank lines in list content are appended as a literal blocks" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      List
      ====

      - Foo

        literal

        more
        literal

      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 2
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 2
      assert_xpath '((//ul/li)[1]/*[@class="literalblock"])[1]//pre[text()="literal"]', output, 1
      assert_xpath "((//ul/li)[1]/*[@class='literalblock'])[2]//pre[text()='more\nliteral']", output, 1
    end

    test "a literal paragraph without a trailing blank line consumes following list items" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      List
      ====

      - Foo

        literal
      - Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 1
      assert_xpath '(//ul/li)[1]/p[text() = "Foo"]', output, 1
      assert_xpath '(//ul/li)[1]/*[@class="literalblock"]', output, 1
      assert_xpath '(//ul/li)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath "((//ul/li)[1]/*[@class='literalblock'])[1]//pre[text() = '  literal\n- Boo\n- Blech']", output, 1
    end

    test "asterisk elements with no blank lines" do
      input = <<~'EOS'
      List
      ====

      * Foo
      * Boo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented asterisk elements using spaces' do
      input = <<~EOS
      \x20* Foo
      \x20* Boo
      \x20* Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented unicode bullet elements using spaces' do
      input = <<~EOS
      \x20• Foo
      \x20• Boo
      \x20• Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'indented asterisk elements using tabs' do
      input = <<~EOS
      \t*\tFoo
      \t*\tBoo
      \t*\tBlech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'should represent block style as style class' do
      ['disc', 'square', 'circle'].each do |style|
        input = <<~EOS
        [#{style}]
        * a
        * b
        * c
        EOS
        output = convert_string_to_embedded input
        assert_css ".ulist.#{style}", output, 1
        assert_css ".ulist.#{style} ul.#{style}", output, 1
      end
    end

    test "asterisk elements separated by blank lines should merge lists" do
      input = <<~'EOS'
      List
      ====

      * Foo

      * Boo


      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
    end

    test 'asterisk elements with interspersed line comments should be skipped and not break list' do
      input = <<~'EOS'
      == List

      * Foo
      // line comment
      // another line comment
      * Boo
      // line comment
      more text
      // another line comment
      * Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath %((//ul/li)[2]/p[text()="Boo\nmore text"]), output, 1
    end

    test "asterisk elements separated by a line comment offset by blank lines should not merge lists" do
      input = <<~'EOS'
      List
      ====

      * Foo
      * Boo

      //

      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test "asterisk elements separated by a block title offset by a blank line should not merge lists" do
      input = <<~'EOS'
      List
      ====

      * Foo
      * Boo

      .Also
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
      assert_xpath '(//ul)[2]/preceding-sibling::*[@class = "title"][text() = "Also"]', output, 1
    end

    test "asterisk elements separated by an attribute entry offset by a blank line should not merge lists" do
      input = <<~'EOS'
      == List

      * Foo
      * Boo

      :foo: bar
      * Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 2
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[2]/li', output, 1
    end

    test "list should terminate before next lower section heading" do
      input = <<~'EOS'
      List
      ====

      * first
      item
      * second
      item

      == Section
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//h2[text() = "Section"]', output, 1
    end

    test "list should terminate before next lower section heading with implicit id" do
      input = <<~'EOS'
      List
      ====

      * first
      item
      * second
      item

      [[sec]]
      == Section
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//h2[@id = "sec"][text() = "Section"]', output, 1
    end

    test 'should not find section title immediately below last list item' do
      input = <<~'EOS'
      * first
      * second
      == Not a section
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul', output, 1
      assert_css 'ul > li', output, 2
      assert_css 'h2', output, 0
      assert_includes output, '== Not a section'
      assert_xpath %((//li)[2]/p[text() = "second\n== Not a section"]), output, 1
    end

    test 'should match trailing line separator in text of list item' do
      input = <<~EOS.chop
      * a
      * b#{decode_char 8232}
      * c
      EOS

      output = convert_string input
      assert_css 'li', output, 3
      assert_xpath %((//li)[2]/p[text()="b#{decode_char 8232}"]), output, 1
    end

    test 'should match line separator in text of list item' do
      input = <<~EOS.chop
      * a
      * b#{decode_char 8232}b
      * c
      EOS

      output = convert_string input
      assert_css 'li', output, 3
      assert_xpath %((//li)[2]/p[text()="b#{decode_char 8232}b"]), output, 1
    end
  end

  context "Lists with inline markup" do
    test "quoted text" do
      input = <<~'EOS'
      List
      ====

      - I am *strong*.
      - I am _stressed_.
      - I am `flexible`.
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul/li)[1]//strong', output, 1
      assert_xpath '(//ul/li)[2]//em', output, 1
      assert_xpath '(//ul/li)[3]//code', output, 1
    end

    test "attribute substitutions" do
      input = <<~'EOS'
      List
      ====
      :foo: bar

      - side a {vbar} side b
      - Take me to a {foo}.
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '(//ul/li)[1]//p[text() = "side a | side b"]', output, 1
      assert_xpath '(//ul/li)[2]//p[text() = "Take me to a bar."]', output, 1
    end

    test "leading dot is treated as text not block title" do
      input = <<~'EOS'
      * .first
      * .second
      * .third
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 3
      %w(.first .second .third).each_with_index do |text, index|
        assert_xpath "(//ul/li)[#{index + 1}]//p[text() = '#{text}']", output, 1
      end
    end

    test "word ending sentence on continuing line not treated as a list item" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      A. This is the story about
         AsciiDoc. It begins here.
      B. And it ends here.
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 2
    end

    test 'should discover anchor at start of unordered list item text and register it as a reference' do
      input = <<~'EOS'
      The highest peak in the Front Range is <<grays-peak>>, which tops <<mount-evans>> by just a few feet.

      * [[mount-evans,Mount Evans]]At 14,271 feet, Mount Evans is the highest summit of the Chicago Peaks in the Front Range of the Rocky Mountains.
      * [[grays-peak,Grays Peak]]
      Grays Peak rises to 14,278 feet, making it the highest summit in the Front Range of the Rocky Mountains.
      * Longs Peak is a 14,259-foot high, prominent mountain summit in the northern Front Range of the Rocky Mountains.
      * Pikes Peak is the highest summit of the southern Front Range of the Rocky Mountains at 14,115 feet.
      EOS

      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('mount-evans')
      assert refs.key?('grays-peak')
      output = doc.convert standalone: false
      assert_xpath '(//p)[1]/a[@href="#grays-peak"][text()="Grays Peak"]', output, 1
      assert_xpath '(//p)[1]/a[@href="#mount-evans"][text()="Mount Evans"]', output, 1
    end

    test 'should discover anchor at start of ordered list item text and register it as a reference' do
      input = <<~'EOS'
      This is a cross-reference to <<step-2>>.
      This is a cross-reference to <<step-4>>.

      . Ordered list, item 1, without anchor
      . [[step-2,Step 2]]Ordered list, item 2, with anchor
      . Ordered list, item 3, without anchor
      . [[step-4,Step 4]]Ordered list, item 4, with anchor
      EOS

      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('step-2')
      assert refs.key?('step-4')
      output = doc.convert standalone: false
      assert_xpath '(//p)[1]/a[@href="#step-2"][text()="Step 2"]', output, 1
      assert_xpath '(//p)[1]/a[@href="#step-4"][text()="Step 4"]', output, 1
    end

    test 'should discover anchor at start of callout list item text and register it as a reference' do
      input = <<~'EOS'
      This is a cross-reference to <<url-mapping>>.

      [source,ruby]
      ----
      require 'sinatra' <1>

      get '/hi' do <2> <3>
        "Hello World!"
      end
      ----
      <1> Library import
      <2> [[url-mapping,url mapping]]URL mapping
      <3> Response block
      EOS

      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('url-mapping')
      output = doc.convert standalone: false
      assert_xpath '(//p)[1]/a[@href="#url-mapping"][text()="url mapping"]', output, 1
    end
  end

  context "Nested lists" do
    test "asterisk element mixed with dash elements should be nested" do
      input = <<~'EOS'
      List
      ====

      - Foo
      * Boo
      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "dash element mixed with asterisks elements should be nested" do
      input = <<~'EOS'
      List
      ====

      * Foo
      - Boo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "lines prefixed with alternating list markers separated by blank lines should be nested" do
      input = <<~'EOS'
      List
      ====

      - Foo

      * Boo


      - Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "nested elements (2) with asterisks" do
      input = <<~'EOS'
      List
      ====

      * Foo
      ** Boo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 2
      assert_xpath '//ul/li', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '(//ul)[1]/li//ul/li', output, 1
    end

    test "nested elements (3) with asterisks" do
      input = <<~'EOS'
      List
      ====

      * Foo
      ** Boo
      *** Snoo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 3
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested elements (4) with asterisks" do
      input = <<~'EOS'
      List
      ====

      * Foo
      ** Boo
      *** Snoo
      **** Froo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 4
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test "nested elements (5) with asterisks" do
      input = <<~'EOS'
      List
      ====

      * Foo
      ** Boo
      *** Snoo
      **** Froo
      ***** Groo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 5
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
      assert_xpath '(((((//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li//ul)[1]/li', output, 1
    end

    test 'nested arbitrary depth with asterisks' do
      input = []
      ('a'..'z').each_with_index do |ch, i|
        input << %(#{'*' * (i + 1)} #{ch})
      end
      output = convert_string_to_embedded input.join(%(\n))
      refute_includes output, '*'
      assert_css 'li', output, 26
    end

    test 'level of unordered list should match section level' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Parent Section

      * item 1.1
       ** item 2.1
        *** item 3.1
       ** item 2.2
      * item 1.2

      === Nested Section

      * item 1.1
      EOS

      doc = document_from_string input
      lists = doc.find_by context: :ulist
      assert_equal 1, lists[0].level
      assert_equal 1, lists[1].level
      assert_equal 1, lists[2].level
      assert_equal 2, lists[3].level
    end

    test 'does not recognize lists with repeating unicode bullets' do
      input = '•• Boo'
      output = convert_string input
      assert_xpath '//ul', output, 0
      assert_includes output, '•'
    end

    test "nested ordered elements (2)" do
      input = <<~'EOS'
      List
      ====

      . Foo
      .. Boo
      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 2
      assert_xpath '//ol/li', output, 3
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[1]/li//ol/li', output, 1
    end

    test "nested ordered elements (3)" do
      input = <<~'EOS'
      List
      ====

      . Foo
      .. Boo
      ... Snoo
      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 3
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '((//ol)[1]/li//ol)[1]/li', output, 1
      assert_xpath '(((//ol)[1]/li//ol)[1]/li//ol)[1]/li', output, 1
    end

    test 'nested arbitrary depth with dot marker' do
      input = []
      ('a'..'z').each_with_index do |ch, i|
        input << %(#{'.' * (i + 1)} #{ch})
      end
      output = convert_string_to_embedded input.join(%(\n))
      refute_includes output, '.'
      assert_css 'li', output, 26
    end

    test 'level of ordered list should match section level' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Parent Section

      . item 1.1
       .. item 2.1
        ... item 3.1
       .. item 2.2
      . item 1.2

      === Nested Section

      . item 1.1
      EOS

      doc = document_from_string input
      lists = doc.find_by context: :olist
      assert_equal 1, lists[0].level
      assert_equal 1, lists[1].level
      assert_equal 1, lists[2].level
      assert_equal 2, lists[3].level
    end

    test "nested unordered inside ordered elements" do
      input = <<~'EOS'
      List
      ====

      . Foo
      * Boo
      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ul', output, 1
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '((//ol)[1]/li//ul)[1]/li', output, 1
    end

    test "nested ordered inside unordered elements" do
      input = <<~'EOS'
      List
      ====

      * Foo
      . Boo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ol', output, 1
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ol)[1]/li', output, 1
    end

    test 'three levels of alternating unordered and ordered elements' do
      input = <<~'EOS'
      == Lists

      * bullet 1
      . numbered 1.1
      ** bullet 1.1.1
      * bullet 2
      EOS

      output = convert_string_to_embedded input
      assert_css '.ulist', output, 2
      assert_css '.olist', output, 1
      assert_css '.ulist > ul > li > p', output, 3
      assert_css '.ulist > ul > li > p + .olist', output, 1
      assert_css '.ulist > ul > li > p + .olist > ol > li > p', output, 1
      assert_css '.ulist > ul > li > p + .olist > ol > li > p + .ulist', output, 1
      assert_css '.ulist > ul > li > p + .olist > ol > li > p + .ulist > ul > li > p', output, 1
      assert_css '.ulist > ul > li + li > p', output, 1
    end

    test "lines with alternating markers of unordered and ordered list types separated by blank lines should be nested" do
      input = <<~'EOS'
      List
      ====

      * Foo

      . Boo


      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ol', output, 1
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ol)[1]/li', output, 1
    end

    test 'list item with literal content should not consume nested list of different type' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      List
      ====

      - bullet

        literal
        but not
        hungry

      . numbered
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//li', output, 2
      assert_xpath '//ul//ol', output, 1
      assert_xpath '//ul/li/p', output, 1
      assert_xpath '//ul/li/p[text()="bullet"]', output, 1
      assert_xpath '//ul/li/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath %(//ul/li/p/following-sibling::*[@class="literalblock"]//pre[text()="literal\nbut not\nhungry"]), output, 1
      assert_xpath '//*[@class="literalblock"]/following-sibling::*[@class="olist arabic"]', output, 1
      assert_xpath '//*[@class="literalblock"]/following-sibling::*[@class="olist arabic"]//p[text()="numbered"]', output, 1
    end

    test 'nested list item does not eat the title of the following detached block' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      List
      ====

      - bullet
        * nested bullet 1
        * nested bullet 2

      .Title
      ....
      literal
      ....
      EOS
      # use convert_string so we can match all ulists easier
      output = convert_string input
      assert_xpath '//*[@class="ulist"]/ul', output, 2
      assert_xpath '(//*[@class="ulist"])[1]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '(//*[@class="ulist"])[1]/following-sibling::*[@class="literalblock"]/*[@class="title"]', output, 1
    end

    test "lines with alternating markers of bulleted and description list types separated by blank lines should be nested" do
      input = <<~'EOS'
      List
      ====

      * Foo

      term1:: def1

      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//dl', output, 1
      assert_xpath '//ul[1]/li', output, 2
      assert_xpath '//ul[1]/li//dl[1]/dt', output, 1
      assert_xpath '//ul[1]/li//dl[1]/dd', output, 1
    end

    test "nested ordered with attribute inside unordered elements" do
      input = <<~'EOS'
      Blah
      ====

      * Foo
      [start=2]
      . Boo
      * Blech
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ol', output, 1
      assert_xpath '(//ul)[1]/li', output, 2
      assert_xpath '((//ul)[1]/li//ol)[1][@start = 2]/li', output, 1
    end
  end

  context "List continuations" do
    test "adjacent list continuation line attaches following paragraph" do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      Item one, paragraph two
      +
      * Item two
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '//ul/li[1]//p', output, 2
      assert_xpath '//ul/li[1]/p[text() = "Item one, paragraph one"]', output, 1
      assert_xpath '//ul/li[1]/*[@class = "paragraph"]/p[text() = "Item one, paragraph two"]', output, 1
    end

    test "adjacent list continuation line attaches following block" do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      ....
      Item one, literal block
      ....
      +
      * Item two
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
    end

    test 'adjacent list continuation line attaches following block with block attributes' do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      :foo: bar
      [[beck]]
      .Read the following aloud to yourself
      [source, ruby]
      ----
      5.times { print "Odelay!" }
      ----

      * Item two
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@id="beck"][@class = "listingblock"]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@id="beck"]/div[@class="title"][starts-with(text(),"Read")]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@id="beck"]//code[@data-lang="ruby"][starts-with(text(),"5.times")]', output, 1
    end

    test 'trailing block attribute line attached by continuation should not create block' do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      [source]

      * Item two
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/*', output, 1
      assert_xpath '//ul/li//*[@class="listingblock"]', output, 0
    end

    test 'trailing block title line attached by continuation should not create block' do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      .Disappears into the ether

      * Item two
      EOS
      output = convert_string input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/*', output, 1
    end

    test 'consecutive blocks in list continuation attach to list item' do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      ....
      Item one, literal block
      ....
      +
      ____
      Item one, quote block
      ____
      +
      * Item two
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[1][@class = "literalblock"]', output, 1
      assert_xpath '(//ul/li[1]/p/following-sibling::*)[2][@class = "quoteblock"]', output, 1
    end

    test 'list item with hanging indent followed by block attached by list continuation' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      . list item 1
        continued
      +
      --
      open block in list item 1
      --

      . list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css 'ol', output, 1
      assert_css 'ol li', output, 2
      assert_xpath %((//ol/li)[1]/p[text()="list item 1\ncontinued"]), output, 1
      assert_xpath '(//ol/li)[1]/p/following-sibling::*[@class="openblock"]', output, 1
      assert_xpath '(//ol/li)[1]/p/following-sibling::*[@class="openblock"]//p[text()="open block in list item 1"]', output, 1
      assert_xpath %((//ol/li)[2]/p[text()="list item 2"]), output, 1
    end

    test 'list item paragraph in list item and nested list item' do
      input = <<~'EOS'
      == Lists

      . list item 1
      +
      list item 1 paragraph

      * nested list item
      +
      nested list item paragraph

      . list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]/ul/li/p[text()="nested list item"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="ulist"]/ul/li/p/following-sibling::div[@class="paragraph"]', output, 1
    end

    test 'trailing list continuations should attach to list items at respective levels' do
      input = <<~'EOS'
      == Lists

      . list item 1
      +
      * nested list item 1
      * nested list item 2
      +
      paragraph for nested list item 2

      +
      paragraph for list item 1

      . list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'trailing list continuations should attach to list items of different types at respective levels' do
      input = <<~'EOS'
      == Lists

      * bullet 1
      . numbered 1.1
      ** bullet 1.1.1

      +
      numbered 1.1 paragraph

      +
      bullet 1 paragraph

      * bullet 2
      EOS
      output = convert_string_to_embedded input

      assert_xpath '(//ul)[1]/li', output, 2

      assert_xpath '((//ul)[1]/li[1])/*', output, 3
      assert_xpath '(((//ul)[1]/li[1])/*)[1]/self::p[text()="bullet 1"]', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[2]/ol', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[3]/self::div[@class="paragraph"]/p[text()="bullet 1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div/ol/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/*', output, 3
      assert_xpath '(((//ul)[1]/li)[1]/div/ol/li/*)[1]/self::p[text()="numbered 1.1"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div/ol/li/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div/ol/li/*)[3]/self::div[@class="paragraph"]/p[text()="numbered 1.1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/div[@class="ulist"]/ul/li/*', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div/ol/li/div[@class="ulist"]/ul/li/p[text()="bullet 1.1.1"]', output, 1
    end

    test 'repeated list continuations should attach to list items at respective levels' do
      input = <<~'EOS'
      == Lists

      . list item 1

      * nested list item 1
      +
      --
      open block for nested list item 1
      --
      +
      * nested list item 2
      +
      paragraph for nested list item 2

      +
      paragraph for list item 1

      . list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/div[@class="openblock"]', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'repeated list continuations attached directly to list item should attach to list items at respective levels' do
      input = <<~'EOS'
      == Lists

      . list item 1
      +
      * nested list item 1
      +
      --
      open block for nested list item 1
      --
      +
      * nested list item 2
      +
      paragraph for nested list item 2

      +
      paragraph for list item 1

      . list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/div[@class="openblock"]', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'repeated list continuations should attach to list items at respective levels ignoring blank lines' do
      input = <<~'EOS'
      == Lists

      . list item 1
      +
      * nested list item 1
      +
      --
      open block for nested list item 1
      --
      +
      * nested list item 2
      +
      paragraph for nested list item 2


      +
      paragraph for list item 1

      . list item 2
      EOS
      output = convert_string_to_embedded input
      assert_css '.olist ol', output, 1
      assert_css '.olist ol > li', output, 2
      assert_css '.ulist ul', output, 1
      assert_css '.ulist ul > li', output, 2
      assert_css '.olist .ulist', output, 1
      assert_xpath '(//ol/li)[1]/*', output, 3
      assert_xpath '((//ol/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ol/li)[1]/*)[1]/self::p[text()="list item 1"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[1]/div[@class="openblock"]', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/*', output, 2
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/p', output, 1
      assert_xpath '(((//ol/li)[1]/*)[2]/self::div[@class="ulist"]/ul/li)[2]/div[@class="paragraph"]', output, 1
      assert_xpath '((//ol/li)[1]/*)[3]/self::div[@class="paragraph"]', output, 1
    end

    test 'trailing list continuations should ignore preceding blank lines' do
      input = <<~'EOS'
      == Lists

      * bullet 1
      ** bullet 1.1
      *** bullet 1.1.1
      +
      --
      open block
      --


      +
      bullet 1.1 paragraph


      +
      bullet 1 paragraph

      * bullet 2
      EOS
      output = convert_string_to_embedded input

      assert_xpath '((//ul)[1]/li[1])/*', output, 3
      assert_xpath '(((//ul)[1]/li[1])/*)[1]/self::p[text()="bullet 1"]', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '(((//ul)[1]/li[1])/*)[3]/self::div[@class="paragraph"]/p[text()="bullet 1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*', output, 3
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*)[1]/self::p[text()="bullet 1.1"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*)[2]/self::div[@class="ulist"]', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/*)[3]/self::div[@class="paragraph"]/p[text()="bullet 1.1 paragraph"]', output, 1

      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li', output, 1
      assert_xpath '((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li/*', output, 2
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li/*)[1]/self::p', output, 1
      assert_xpath '(((//ul)[1]/li)[1]/div[@class="ulist"]/ul/li/div[@class="ulist"]/ul/li/*)[2]/self::div[@class="openblock"]', output, 1
    end

    test 'indented outline list item with different marker offset by a blank line should be recognized as a nested list' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      * item 1

        . item 1.1
      +
      attached paragraph

        . item 1.2
      +
      attached paragraph

      * item 2
      EOS

      output = convert_string_to_embedded input

      assert_css 'ul', output, 1
      assert_css 'ol', output, 1
      assert_css 'ul ol', output, 1
      assert_css 'ul > li', output, 2
      assert_xpath '((//ul/li)[1]/*)', output, 2
      assert_xpath '((//ul/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/ol', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/ol/li', output, 2
      (1..2).each do |idx|
        assert_xpath "(((//ul/li)[1]/*)[2]/self::div/ol/li)[#{idx}]/*", output, 2
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/ol/li)[#{idx}]/*)[1]/self::p", output, 1
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/ol/li)[#{idx}]/*)[2]/self::div[@class=\"paragraph\"]", output, 1
      end
    end

    test 'indented description list item inside outline list item offset by a blank line should be recognized as a nested list' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      * item 1

        term a:: description a
      +
      attached paragraph

        term b:: description b
      +
      attached paragraph

      * item 2
      EOS

      output = convert_string_to_embedded input

      assert_css 'ul', output, 1
      assert_css 'dl', output, 1
      assert_css 'ul dl', output, 1
      assert_css 'ul > li', output, 2
      assert_xpath '((//ul/li)[1]/*)', output, 2
      assert_xpath '((//ul/li)[1]/*)[1]/self::p', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/dl', output, 1
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/dl/dt', output, 2
      assert_xpath '((//ul/li)[1]/*)[2]/self::div/dl/dd', output, 2
      (1..2).each do |idx|
        assert_xpath "(((//ul/li)[1]/*)[2]/self::div/dl/dd)[#{idx}]/*", output, 2
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/dl/dd)[#{idx}]/*)[1]/self::p", output, 1
        assert_xpath "((((//ul/li)[1]/*)[2]/self::div/dl/dd)[#{idx}]/*)[2]/self::div[@class=\"paragraph\"]", output, 1
      end
    end

    # NOTE this is not consistent w/ AsciiDoc.py, but this is some screwy input anyway
    # FIXME one list continuation is left behind
    test 'consecutive list continuation lines are folded' do
      input = <<~'EOS'
      Lists
      =====

      * Item one, paragraph one
      +
      +
      Item one, paragraph two
      +
      +
      * Item two
      +
      +
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ul', output, 1
      assert_xpath '//ul/li', output, 2
      assert_xpath '//ul/li[1]/p', output, 1
      assert_xpath '//ul/li[1]/div/p', output, 1
      assert_xpath '//ul/li[1]//p[text() = "Item one, paragraph one"]', output, 1
      # NOTE this is a negative assertion
      assert_xpath %(//ul/li[1]//p[text() = "+\nItem one, paragraph two"]), output, 1
    end

    test 'should warn if unterminated block is detected in list item' do
      input = <<~'EOS'
      * item
      +
      ====
      example
      * swallowed item
      EOS

      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_xpath '//ul/li', output, 1
        assert_xpath '//ul/li/*[@class="exampleblock"]', output, 1
        assert_xpath %(//p[text()="example\n* swallowed item"]), output, 1
        assert_message logger, :WARN, '<stdin>: line 3: unterminated example block', Hash
      end
    end
  end
end

context "Ordered lists (:olist)" do
  context "Simple lists" do
    test "dot elements with no blank lines" do
      input = <<~'EOS'
      List
      ====

      . Foo
      . Boo
      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'indented dot elements using spaces' do
      input = <<~EOS
      \x20. Foo
      \x20. Boo
      \x20. Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'indented dot elements using tabs' do
      input = <<~EOS
      \t.\tFoo
      \t.\tBoo
      \t.\tBlech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'should represent explicit role attribute as style class' do
      input = <<~'EOS'
      [role="dry"]
      . Once
      . Again
      . Refactor!
      EOS

      output = convert_string_to_embedded input
      assert_css '.olist.arabic.dry', output, 1
      assert_css '.olist ol.arabic', output, 1
    end

    test 'should base list style on marker length rather than list depth' do
      input = <<~'EOS'
      ... parent
      .. child
      . grandchild
      EOS

      output = convert_string_to_embedded input
      assert_css '.olist.lowerroman', output, 1
      assert_css '.olist.lowerroman .olist.loweralpha', output, 1
      assert_css '.olist.lowerroman .olist.loweralpha .olist.arabic', output, 1
    end

    test 'should allow list style to be specified explicitly when using markers with implicit style' do
      input = <<~'EOS'
      [loweralpha]
      i) 1
      ii) 2
      iii) 3
      EOS

      output = convert_string_to_embedded input
      assert_css '.olist.loweralpha', output, 1
      assert_css '.olist.lowerroman', output, 0
    end

    test 'should represent custom numbering and explicit role attribute as style classes' do
      input = <<~'EOS'
      [loweralpha, role="dry"]
      . Once
      . Again
      . Refactor!
      EOS

      output = convert_string_to_embedded input
      assert_css '.olist.loweralpha.dry', output, 1
      assert_css '.olist ol.loweralpha', output, 1
    end

    test 'should set reversed attribute on list if reversed option is set' do
      input = <<~'EOS'
      [%reversed, start=3]
      . three
      . two
      . one
      . blast off!
      EOS

      output = convert_string_to_embedded input
      assert_css 'ol[reversed][start="3"]', output, 1
    end

    test 'should represent implicit role attribute as style class' do
      input = <<~'EOS'
      [.dry]
      . Once
      . Again
      . Refactor!
      EOS

      output = convert_string_to_embedded input
      assert_css '.olist.arabic.dry', output, 1
      assert_css '.olist ol.arabic', output, 1
    end

    test 'should represent custom numbering and implicit role attribute as style classes' do
      input = <<~'EOS'
      [loweralpha.dry]
      . Once
      . Again
      . Refactor!
      EOS

      output = convert_string_to_embedded input
      assert_css '.olist.loweralpha.dry', output, 1
      assert_css '.olist ol.loweralpha', output, 1
    end

    test "dot elements separated by blank lines should merge lists" do
      input = <<~'EOS'
      List
      ====

      . Foo

      . Boo


      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
    end

    test 'should escape special characters in all literal paragraphs attached to list item' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      . first item

        <code>text</code>

        more <code>text</code>

      . second item
      EOS

      output = convert_string_to_embedded input
      assert_css 'li', output, 2
      assert_css 'code', output, 0
      assert_css 'li:first-of-type > *', output, 3
      assert_css 'li:first-of-type pre', output, 2
      assert_xpath '((//li)[1]//pre)[1][text()="<code>text</code>"]', output, 1
      assert_xpath '((//li)[1]//pre)[2][text()="more <code>text</code>"]', output, 1
    end

    test 'dot elements with interspersed line comments should be skipped and not break list' do
      input = <<~'EOS'
      == List

      . Foo
      // line comment
      // another line comment
      . Boo
      // line comment
      more text
      // another line comment
      . Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ol', output, 1
      assert_xpath '//ol/li', output, 3
      assert_xpath %((//ol/li)[2]/p[text()="Boo\nmore text"]), output, 1
    end

    test "dot elements separated by line comment offset by blank lines should not merge lists" do
      input = <<~'EOS'
      List
      ====

      . Foo
      . Boo

      //

      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 2
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[2]/li', output, 1
    end

    test "dot elements separated by a block title offset by a blank line should not merge lists" do
      input = <<~'EOS'
      List
      ====

      . Foo
      . Boo

      .Also
      . Blech
      EOS
      output = convert_string input
      assert_xpath '//ol', output, 2
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[2]/li', output, 1
      assert_xpath '(//ol)[2]/preceding-sibling::*[@class = "title"][text() = "Also"]', output, 1
    end

    test "dot elements separated by an attribute entry offset by a blank line should not merge lists" do
      input = <<~'EOS'
      == List

      . Foo
      . Boo

      :foo: bar
      . Blech
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//ol', output, 2
      assert_xpath '(//ol)[1]/li', output, 2
      assert_xpath '(//ol)[2]/li', output, 1
    end

    test 'should use start number in docbook5 backend' do
      input = <<~'EOS'
      == List

      [start=7]
      . item 7
      . item 8
      EOS

      output = convert_string_to_embedded input, backend: 'docbook5'
      assert_xpath '//orderedlist', output, 1
      assert_xpath '(//orderedlist)/listitem', output, 2
      assert_xpath '(//orderedlist)[@startingnumber = "7"]', output, 1
    end

    test 'should match trailing line separator in text of list item' do
      input = <<~EOS.chop
      . a
      . b#{decode_char 8232}
      . c
      EOS

      output = convert_string input
      assert_css 'li', output, 3
      assert_xpath %((//li)[2]/p[text()="b#{decode_char 8232}"]), output, 1
    end

    test 'should match line separator in text of list item' do
      input = <<~EOS.chop
      . a
      . b#{decode_char 8232}b
      . c
      EOS

      output = convert_string input
      assert_css 'li', output, 3
      assert_xpath %((//li)[2]/p[text()="b#{decode_char 8232}b"]), output, 1
    end
  end

  test 'should warn if explicit uppercase roman numerals in list are out of sequence' do
    input = <<~'EOS'
    I) one
    III) three
    EOS
    using_memory_logger do |logger|
      output = convert_string_to_embedded input
      assert_xpath '//ol/li', output, 2
      assert_message logger, :WARN, '<stdin>: line 2: list item index: expected II, got III', Hash
    end
  end

  test 'should warn if explicit lowercase roman numerals in list are out of sequence' do
    input = <<~'EOS'
    i) one
    iii) three
    EOS
    using_memory_logger do |logger|
      output = convert_string_to_embedded input
      assert_xpath '//ol/li', output, 2
      assert_message logger, :WARN, '<stdin>: line 2: list item index: expected ii, got iii', Hash
    end
  end
end

context "Description lists (:dlist)" do
  context "Simple lists" do
    test 'should not parse a bare dlist delimiter as a dlist' do
      input = '::'
      output = convert_string_to_embedded input
      assert_css 'dl', output, 0
      assert_xpath '//p[text()="::"]', output, 1
    end

    test 'should not parse an indented bare dlist delimiter as a dlist' do
      input = ' ::'
      output = convert_string_to_embedded input
      assert_css 'dl', output, 0
      assert_xpath '//pre[text()="::"]', output, 1
    end

    test 'should parse a dlist delimiter preceded by a blank attribute as a dlist' do
      input = '{blank}::'
      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 1
      assert_css 'dl > dt:empty', output, 1
    end

    test 'should parse a dlist if term is include and principal text is []' do
      input = 'include:: []'
      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "[]"]', output, 1
    end

    test 'should parse a dlist if term is include and principal text matches macro form' do
      input = 'include:: pass:[${placeholder}]'
      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "${placeholder}"]', output, 1
    end

    test "single-line adjacent elements" do
      input = <<~'EOS'
      term1:: def1
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'should parse sibling items using same rules' do
      input = <<~'EOS'
      term1;; ;; def1
      term2;; ;; def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = ";; def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = ";; def2"]', output, 1
    end

    test 'should allow term to end with a semicolon when using double semicolon delimiter' do
      input = <<~'EOS'
      term;;; def
      EOS
      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 1
      assert_xpath '(//dl/dt)[1][text() = "term;"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def"]', output, 1
    end

    test "single-line indented adjacent elements" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1:: def1
       term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line indented adjacent elements with tabs" do
      input = <<~EOS
      term1::\tdef1
      \tterm2::\tdef2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line elements separated by blank line should create a single list" do
      input = <<~'EOS'
      term1:: def1

      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
    end

    test "a line comment between elements should divide them into separate lists" do
      input = <<~'EOS'
      term1:: def1

      //

      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl)[1]/dt', output, 1
      assert_xpath '(//dl)[2]/dt', output, 1
    end

    test "a ruler between elements should divide them into separate lists" do
      input = <<~'EOS'
      term1:: def1

      '''

      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl//hr', output, 0
      assert_xpath '(//dl)[1]/dt', output, 1
      assert_xpath '(//dl)[2]/dt', output, 1
    end

    test "a block title between elements should divide them into separate lists" do
      input = <<~'EOS'
      term1:: def1

      .Some more
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl)[1]/dt', output, 1
      assert_xpath '(//dl)[2]/dt', output, 1
      assert_xpath '(//dl)[2]/preceding-sibling::*[@class="title"][text() = "Some more"]', output, 1
    end

    test "multi-line elements with paragraph content" do
      input = <<~'EOS'
      term1::
      def1
      term2::
      def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with indented paragraph content" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::
       def1
      term2::
        def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with indented paragraph content that includes comment lines" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::
       def1
      // comment
      term2::
        def2
      // comment
        def2 continued
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath %((//dl/dt)[2]/following-sibling::dd/p[text() = "def2\ndef2 continued"]), output, 1
    end

    test "should not strip comment line in literal paragraph block attached to list item" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::
      +
       line 1
      // not a comment
       line 3
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//*[@class="literalblock"]', output, 1
      assert_xpath %(//*[@class="literalblock"]//pre[text()=" line 1\n// not a comment\n line 3"]), output, 1
    end

    test 'should escape special characters in all literal paragraphs attached to list item' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term:: desc

        <code>text</code>

        more <code>text</code>

      another term::

        <code>text</code> in a paragraph
      EOS

      output = convert_string_to_embedded input
      assert_css 'dt', output, 2
      assert_css 'code', output, 0
      assert_css 'dd:first-of-type > *', output, 3
      assert_css 'dd:first-of-type pre', output, 2
      assert_xpath '((//dd)[1]//pre)[1][text()="<code>text</code>"]', output, 1
      assert_xpath '((//dd)[1]//pre)[2][text()="more <code>text</code>"]', output, 1
      assert_xpath '((//dd)[2]//p)[1][text()="<code>text</code> in a paragraph"]', output, 1
    end

    test 'multi-line element with paragraph starting with multiple dashes should not be seen as list' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::
        def1
        -- and a note

      term2::
        def2
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath %((//dl/dt)[1]/following-sibling::dd/p[text() = "def1#{decode_char 8201}#{decode_char 8212}#{decode_char 8201}and a note"]), output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line element with multiple terms" do
      input = <<~'EOS'
      term1::
      term2::
      def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dt', output, 1
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'consecutive terms share same varlistentry in docbook' do
      input = <<~'EOS'
      term::
      alt term::
      description

      last::
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '//varlistentry', output, 2
      assert_xpath '(//varlistentry)[1]/term', output, 2
      assert_xpath '(//varlistentry)[2]/term', output, 1
      assert_xpath '(//varlistentry)[2]/listitem', output, 1
      assert_xpath '(//varlistentry)[2]/listitem[normalize-space(text())=""]', output, 1
    end

    test "multi-line elements with blank line before paragraph content" do
      input = <<~'EOS'
      term1::

      def1
      term2::

      def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with paragraph and literal content" do
      # blank line following literal paragraph is required or else it will gobble up the second term
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::
      def1

        literal

      term2::
        def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '//dl/dt/following-sibling::dd//pre', output, 1
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "mixed single and multi-line adjacent elements" do
      input = <<~'EOS'
      term1:: def1
      term2::
      def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dt/following-sibling::dd', output, 2
      assert_xpath '(//dl/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'should discover anchor at start of description term text and register it as a reference' do
      input = <<~'EOS'
      The highest peak in the Front Range is <<grays-peak>>, which tops <<mount-evans>> by just a few feet.

      [[mount-evans,Mount Evans]]Mount Evans:: 14,271 feet
      [[grays-peak]]Grays Peak:: 14,278 feet
      EOS
      doc = document_from_string input
      refs = doc.catalog[:refs]
      assert refs.key?('mount-evans')
      assert refs.key?('grays-peak')
      output = doc.convert standalone: false
      assert_xpath '(//p)[1]/a[@href="#grays-peak"][text()="Grays Peak"]', output, 1
      assert_xpath '(//p)[1]/a[@href="#mount-evans"][text()="Mount Evans"]', output, 1
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dt', output, 2
      assert_xpath '(//dl/dt)[1]/a[@id="mount-evans"]', output, 1
      assert_xpath '(//dl/dt)[2]/a[@id="grays-peak"]', output, 1
    end

    test "missing space before term does not produce description list" do
      input = <<~'EOS'
      term1::def1
      term2::def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 0
    end

    test "literal block inside description list" do
      input = <<~'EOS'
      term::
      +
      ....
      literal, line 1

      literal, line 2
      ....
      anotherterm:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd//pre', output, 1
      assert_xpath '(//dl/dd)[1]/*[@class="literalblock"]//pre', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def"]', output, 1
    end

    test "literal block inside description list with trailing line continuation" do
      input = <<~'EOS'
      term::
      +
      ....
      literal, line 1

      literal, line 2
      ....
      +
      anotherterm:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd//pre', output, 1
      assert_xpath '(//dl/dd)[1]/*[@class="literalblock"]//pre', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def"]', output, 1
    end

    test "multiple listing blocks inside description list" do
      input = <<~'EOS'
      term::
      +
      ----
      listing, line 1

      listing, line 2
      ----
      +
      ----
      listing, line 1

      listing, line 2
      ----
      anotherterm:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dt', output, 2
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd//pre', output, 2
      assert_xpath '(//dl/dd)[1]/*[@class="listingblock"]//pre', output, 2
      assert_xpath '(//dl/dd)[2]/p[text() = "def"]', output, 1
    end

    test "open block inside description list" do
      input = <<~'EOS'
      term::
      +
      --
      Open block as description of term.

      And some more detail...
      --
      anotherterm:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dd//p', output, 3
      assert_xpath '(//dl/dd)[1]//*[@class="openblock"]//p', output, 2
    end

    test "paragraph attached by a list continuation on either side in a description list" do
      input = <<~'EOS'
      term1:: def1
      +
      more detail
      +
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '(//dl/dt)[1][normalize-space(text())="term1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text())="term2"]', output, 1
      assert_xpath '(//dl/dd)[1]//p', output, 2
      assert_xpath '((//dl/dd)[1]//p)[1][text()="def1"]', output, 1
      assert_xpath '(//dl/dd)[1]/p/following-sibling::*[@class="paragraph"]/p[text() = "more detail"]', output, 1
    end

    test "paragraph attached by a list continuation on either side to a multi-line element in a description list" do
      input = <<~'EOS'
      term1::
      def1
      +
      more detail
      +
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '(//dl/dt)[1][normalize-space(text())="term1"]', output, 1
      assert_xpath '(//dl/dt)[2][normalize-space(text())="term2"]', output, 1
      assert_xpath '(//dl/dd)[1]//p', output, 2
      assert_xpath '((//dl/dd)[1]//p)[1][text()="def1"]', output, 1
      assert_xpath '(//dl/dd)[1]/p/following-sibling::*[@class="paragraph"]/p[text() = "more detail"]', output, 1
    end

    test 'should continue to parse subsequent blocks attached to list item after first block is dropped' do
      input = <<~'EOS'
      :attribute-missing: drop-line

      term::
      +
      image::{unresolved}[]
      +
      paragraph
      EOS

      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 1
      assert_css 'dl > dt + dd', output, 1
      assert_css 'dl > dt + dd > .imageblock', output, 0
      assert_css 'dl > dt + dd > .paragraph', output, 1
    end

    test "verse paragraph inside a description list" do
      input = <<~'EOS'
      term1:: def
      +
      [verse]
      la la la

      term2:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dd//p', output, 2
      assert_xpath '(//dl/dd)[1]/*[@class="verseblock"]/pre[text() = "la la la"]', output, 1
    end

    test "list inside a description list" do
      input = <<~'EOS'
      term1::
      * level 1
      ** level 2
      * level 1
      term2:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd/p', output, 1
      assert_xpath '(//dl/dd)[1]//ul', output, 2
      assert_xpath '((//dl/dd)[1]//ul)[1]//ul', output, 1
    end

    test "list inside a description list offset by blank lines" do
      input = <<~'EOS'
      term1::

      * level 1
      ** level 2
      * level 1

      term2:: def
      EOS
      output = convert_string input
      assert_xpath '//dl/dd', output, 2
      assert_xpath '//dl/dd/p', output, 1
      assert_xpath '(//dl/dd)[1]//ul', output, 2
      assert_xpath '((//dl/dd)[1]//ul)[1]//ul', output, 1
    end

    test "should only grab one line following last item if item has no inline description" do
      input = <<~'EOS'
      term1::

      def1

      term2::

      def2

      A new paragraph

      Another new paragraph
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def2"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 2
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[1]/p[text() = "A new paragraph"]', output, 1
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[2]/p[text() = "Another new paragraph"]', output, 1
    end

    test "should only grab one literal line following last item if item has no inline description" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::

      def1

      term2::

        def2

      A new paragraph

      Another new paragraph
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def2"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 2
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[1]/p[text() = "A new paragraph"]', output, 1
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[2]/p[text() = "Another new paragraph"]', output, 1
    end

    test "should append subsequent paragraph literals to list item as block content" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::

      def1

      term2::

        def2

        literal

      A new paragraph.
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text() = "def1"]', output, 1
      assert_xpath '(//dl/dd)[2]/p[text() = "def2"]', output, 1
      assert_xpath '(//dl/dd)[2]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '(//dl/dd)[2]/p/following-sibling::*[@class="literalblock"]//pre[text() = "literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '(//*[@class="dlist"]/following-sibling::*[@class="paragraph"])[1]/p[text() = "A new paragraph."]', output, 1
    end

    test 'should not match comment line that looks like description list term' do
      input = <<~'EOS'
      before

      //key:: val

      after
      EOS

      output = convert_string_to_embedded input
      assert_css 'dl', output, 0
    end

    test 'should not match comment line following list that looks like description list term' do
      input = <<~'EOS'
      * item

      //term:: desc
      == Section

      section text
      EOS

      output = convert_string_to_embedded input
      assert_xpath '/*[@class="ulist"]', output, 1
      assert_xpath '/*[@class="sect1"]', output, 1
      assert_xpath '/*[@class="sect1"]/h2[text()="Section"]', output, 1
      assert_xpath '/*[@class="ulist"]/following-sibling::*[@class="sect1"]', output, 1
    end

    test 'should not match comment line that looks like sibling description list term' do
      input = <<~'EOS'
      before

      foo:: bar
      //yin:: yang

      after
      EOS

      output = convert_string_to_embedded input
      assert_css '.dlist', output, 1
      assert_css '.dlist dt', output, 1
      refute_includes output, 'yin'
    end

    test 'should not hang on description list item in list that begins with ///' do
      input = <<~'EOS'
      * a
      ///b::
      c
      EOS

      output = convert_string_to_embedded input
      assert_css 'ul', output, 1
      assert_css 'ul li dl', output, 1
      assert_xpath '//ul/li/p[text()="a"]', output, 1
      assert_xpath '//dt[text()="///b"]', output, 1
      assert_xpath '//dd/p[text()="c"]', output, 1
    end

    test 'should not hang on sibling description list item that begins with ///' do
      input = <<~'EOS'
      a::
      ///b::
      c
      EOS

      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_xpath '(//dl/dt)[1][text()="a"]', output, 1
      assert_xpath '(//dl/dt)[2][text()="///b"]', output, 1
      assert_xpath '//dl/dd/p[text()="c"]', output, 1
    end

    test 'should skip dlist term that begins with // unless it begins with ///' do
      input = <<~'EOS'
      category a::
      //ignored term:: def

      category b::
      ///term:: def
      EOS

      output = convert_string_to_embedded input
      refute_includes output, 'ignored term'
      assert_xpath '//dt[text()="///term"]', output, 1
    end

    test 'more than 4 consecutive colons should become part of description list term' do
      input = <<~'EOS'
      A term::::: a description
      EOS

      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 1
      assert_xpath '//dl/dt[text()="A term:"]', output, 1
      assert_xpath '//dl/dd/p[text()="a description"]', output, 1
    end

    test 'text method of dd node should return nil if dd node only contains blocks' do
      input = <<~'EOS'
      term::
      +
      paragraph
      EOS

      doc = document_from_string input
      dd = doc.blocks[0].items[0][1]
      assert_nil dd.text
    end

    test 'should match trailing line separator in text of list item' do
      input = <<~EOS.chop
      A:: a
      B:: b#{decode_char 8232}
      C:: c
      EOS

      output = convert_string input
      assert_css 'dd', output, 3
      assert_xpath %((//dd)[2]/p[text()="b#{decode_char 8232}"]), output, 1
    end

    test 'should match line separator in text of list item' do
      input = <<~EOS.chop
      A:: a
      B:: b#{decode_char 8232}b
      C:: c
      EOS

      output = convert_string input
      assert_css 'dd', output, 3
      assert_xpath %((//dd)[2]/p[text()="b#{decode_char 8232}b"]), output, 1
    end
  end

  context "Nested lists" do
    test 'should not parse a nested dlist delimiter without a term as a dlist' do
      input = <<~'EOS'
      t::
      ;;
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 1
      assert_xpath '//dl/dd/p[text()=";;"]', output, 1
    end

    test 'should not parse a nested indented dlist delimiter without a term as a dlist' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      t::
      desc
        ;;
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 1
      assert_xpath %(//dl/dd/p[text()="desc\n  ;;"]), output, 1
    end

    test "single-line adjacent nested elements" do
      input = <<~'EOS'
      term1:: def1
      label1::: detail1
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line adjacent maximum nested elements" do
      input = <<~'EOS'
      term1:: def1
      label1::: detail1
      name1:::: value1
      item1;; price1
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 4
      assert_xpath '//dl//dl//dl//dl', output, 1
    end

    test 'single-line nested elements separated by blank line at top level' do
      input = <<~'EOS'
      term1:: def1

      label1::: detail1

      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'single-line nested elements separated by blank line at nested level' do
      input = <<~'EOS'
      term1:: def1
      label1::: detail1

      label2::: detail2
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "single-line adjacent nested elements with alternate delimiters" do
      input = <<~'EOS'
      term1:: def1
      label1;; detail1
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line adjacent nested elements" do
      input = <<~'EOS'
      term1::
      def1
      label1:::
      detail1
      term2::
      def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test 'multi-line nested elements separated by blank line at nested level repeated' do
      input = <<~'EOS'
      term1::
      def1
      label1:::

      detail1
      label2:::
      detail2

      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '(//dl//dl/dt)[1][normalize-space(text()) = "label1"]', output, 1
      assert_xpath '(//dl//dl/dt)[1]/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl//dl/dt)[2][normalize-space(text()) = "label2"]', output, 1
      assert_xpath '(//dl//dl/dt)[2]/following-sibling::dd/p[text() = "detail2"]', output, 1
    end

    test "multi-line element with indented nested element" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1::
        def1
        label1;;
         detail1
      term2::
        def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt', output, 2
      assert_xpath '(//dl)[1]/dd', output, 2
      assert_xpath '((//dl)[1]/dt)[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '((//dl)[1]/dt)[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '((//dl)[1]/dt)[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '((//dl)[1]/dt)[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "mixed single and multi-line elements with indented nested elements" do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      term1:: def1
        label1:::
         detail1
      term2:: def2
      EOS
      output = convert_string input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[text() = "def1"]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
      assert_xpath '(//dl)[1]/dt[2][normalize-space(text()) = "term2"]', output, 1
      assert_xpath '(//dl)[1]/dt[2]/following-sibling::dd/p[text() = "def2"]', output, 1
    end

    test "multi-line elements with first paragraph folded to text with adjacent nested element" do
      input = <<~'EOS'
      term1:: def1
      continued
      label1:::
      detail1
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "term1"]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[starts-with(text(), "def1")]', output, 1
      assert_xpath '(//dl)[1]/dt[1]/following-sibling::dd/p[contains(text(), "continued")]', output, 1
      assert_xpath '//dl//dl/dt[normalize-space(text()) = "label1"]', output, 1
      assert_xpath '//dl//dl/dt/following-sibling::dd/p[text() = "detail1"]', output, 1
    end

    test 'nested dlist attached by list continuation should not consume detached paragraph' do
      input = <<~'EOS'
      term:: text
      +
      nested term::: text

      paragraph
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_css '.dlist .paragraph', output, 0
      assert_css '.dlist + .paragraph', output, 1
    end

    test 'nested dlist with attached block offset by empty line' do
      input = <<~'EOS'
      category::

      term 1:::
      +
      --
      def 1
      --
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 2
      assert_xpath '//dl//dl', output, 1
      assert_xpath '(//dl)[1]/dt[1][normalize-space(text()) = "category"]', output, 1
      assert_xpath '(//dl)[1]//dl/dt[1][normalize-space(text()) = "term 1"]', output, 1
      assert_xpath '(//dl)[1]//dl/dt[1]/following-sibling::dd//p[starts-with(text(), "def 1")]', output, 1
    end
  end

  context 'Special lists' do
    test 'should convert glossary list with proper semantics' do
      input = <<~'EOS'
      [glossary]
      term 1:: def 1
      term 2:: def 2
      EOS
      output = convert_string_to_embedded input
      assert_css '.dlist.glossary', output, 1
      assert_css '.dlist dt:not([class])', output, 2
    end

    test 'consecutive glossary terms should share same glossentry element in docbook' do
      input = <<~'EOS'
      [glossary]
      term::
      alt term::
      description

      last::
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '/glossentry', output, 2
      assert_xpath '(/glossentry)[1]/glossterm', output, 2
      assert_xpath '(/glossentry)[2]/glossterm', output, 1
      assert_xpath '(/glossentry)[2]/glossdef', output, 1
      assert_xpath '(/glossentry)[2]/glossdef[normalize-space(text())=""]', output, 1
    end

    test 'should convert horizontal list with proper markup' do
      input = <<~'EOS'
      [horizontal]
      first term:: description
      +
      more detail

      second term:: description
      EOS
      output = convert_string_to_embedded input
      assert_css '.hdlist', output, 1
      assert_css '.hdlist table', output, 1
      assert_css '.hdlist table colgroup', output, 0
      assert_css '.hdlist table tr', output, 2
      # see nokogiri#1803 for why this is necessary
      tbody_path = jruby? ? 'tbody/' : ''
      refute_includes output, '<tbody>'
      assert_xpath %(/*[@class="hdlist"]/table/#{tbody_path}tr[1]/td), output, 2
      assert_xpath %(/*[@class="hdlist"]/table/#{tbody_path}tr[1]/td[@class="hdlist1"]), output, 1
      assert_xpath %(/*[@class="hdlist"]/table/#{tbody_path}tr[1]/td[@class="hdlist2"]), output, 1
      assert_xpath %(/*[@class="hdlist"]/table/#{tbody_path}tr[1]/td[@class="hdlist2"]/p), output, 1
      assert_xpath %(/*[@class="hdlist"]/table/#{tbody_path}tr[1]/td[@class="hdlist2"]/p/following-sibling::*[@class="paragraph"]), output, 1
      assert_xpath '((//tr)[1]/td)[1][normalize-space(text())="first term"]', output, 1
      assert_xpath '((//tr)[1]/td)[2]/p[normalize-space(text())="description"]', output, 1

      assert_xpath %(/*[@class="hdlist"]/table/#{tbody_path}tr[2]/td), output, 2
      assert_xpath '((//tr)[2]/td)[1][normalize-space(text())="second term"]', output, 1
      assert_xpath '((//tr)[2]/td)[2]/p[normalize-space(text())="description"]', output, 1
    end

    test 'should set col widths of item and label if specified' do
      input = <<~'EOS'
      [horizontal]
      [labelwidth="25", itemwidth="75"]
      term:: def
      EOS

      output = convert_string_to_embedded input
      assert_css 'table', output, 1
      assert_css 'table > colgroup', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_xpath '(//table/colgroup/col)[1][@style="width: 25%;"]', output, 1
      assert_xpath '(//table/colgroup/col)[2][@style="width: 75%;"]', output, 1
    end

    test 'should set col widths of item and label in docbook if specified' do
      input = <<~'EOS'
      [horizontal]
      [labelwidth="25", itemwidth="75"]
      term:: def
      EOS

      output = convert_string_to_embedded input, backend: 'docbook'
      assert_css 'informaltable', output, 1
      assert_css 'informaltable > tgroup', output, 1
      assert_css 'informaltable > tgroup > colspec', output, 2
      assert_xpath '(/informaltable/tgroup/colspec)[1][@colwidth="25*"]', output, 1
      assert_xpath '(/informaltable/tgroup/colspec)[2][@colwidth="75*"]', output, 1
    end

    test 'should add strong class to label if strong option is set' do
      input = <<~'EOS'
      [horizontal, options="strong"]
      term:: def
      EOS

      output = convert_string_to_embedded input
      assert_css '.hdlist', output, 1
      assert_css '.hdlist td.hdlist1.strong', output, 1
    end

    test 'consecutive terms in horizontal list should share same cell' do
      input = <<~'EOS'
      [horizontal]
      term::
      alt term::
      description

      last::
      EOS
      output = convert_string_to_embedded input
      assert_xpath '//tr', output, 2
      assert_xpath '(//tr)[1]/td[@class="hdlist1"]', output, 1
      # NOTE I'm trimming the trailing <br> in Asciidoctor
      #assert_xpath '(//tr)[1]/td[@class="hdlist1"]/br', output, 2
      assert_xpath '(//tr)[1]/td[@class="hdlist1"]/br', output, 1
      assert_xpath '(//tr)[2]/td[@class="hdlist2"]', output, 1
    end

    test 'consecutive terms in horizontal list should share same entry in docbook' do
      input = <<~'EOS'
      [horizontal]
      term::
      alt term::
      description

      last::
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '//row', output, 2
      assert_xpath '(//row)[1]/entry', output, 2
      assert_xpath '((//row)[1]/entry)[1]/simpara', output, 2
      assert_xpath '(//row)[2]/entry', output, 2
      assert_xpath '((//row)[2]/entry)[2][normalize-space(text())=""]', output, 1
    end

    test 'should convert horizontal list in docbook with proper markup' do
      input = <<~'EOS'
      .Terms
      [horizontal]
      first term:: description
      +
      more detail

      second term:: description
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '/table', output, 1
      assert_xpath '/table[@tabstyle="horizontal"]', output, 1
      assert_xpath '/table[@tabstyle="horizontal"]/title[text()="Terms"]', output, 1
      assert_xpath '/table//row', output, 2
      assert_xpath '(/table//row)[1]/entry', output, 2
      assert_xpath '(/table//row)[2]/entry', output, 2
      assert_xpath '((/table//row)[1]/entry)[2]/simpara', output, 2
    end

    test 'should convert qanda list in HTML with proper semantics' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [qanda]
      Question 1::
              Answer 1.
      Question 2::
              Answer 2.
      +
      NOTE: A note about Answer 2.
      EOS
      output = convert_string_to_embedded input
      assert_css '.qlist.qanda', output, 1
      assert_css '.qanda > ol', output, 1
      assert_css '.qanda > ol > li', output, 2
      (1..2).each do |idx|
        assert_css ".qanda > ol > li:nth-child(#{idx}) > p", output, 2
        assert_css ".qanda > ol > li:nth-child(#{idx}) > p:first-child > em", output, 1
        assert_xpath "/*[@class = 'qlist qanda']/ol/li[#{idx}]/p[1]/em[normalize-space(text()) = 'Question #{idx}']", output, 1
        assert_css ".qanda > ol > li:nth-child(#{idx}) > p:last-child > *", output, 0
        assert_xpath "/*[@class = 'qlist qanda']/ol/li[#{idx}]/p[2][normalize-space(text()) = 'Answer #{idx}.']", output, 1
      end
      assert_xpath "/*[@class = 'qlist qanda']/ol/li[2]/p[2]/following-sibling::div[@class='admonitionblock note']", output, 1
    end

    test 'should convert qanda list in DocBook with proper semantics' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [qanda]
      Question 1::
              Answer 1.
      Question 2::
              Answer 2.
      +
      NOTE: A note about Answer 2.
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_css 'qandaset', output, 1
      assert_css 'qandaset > qandaentry', output, 2
      (1..2).each do |idx|
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > question", output, 1
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > question > simpara", output, 1
        assert_xpath "/qandaset/qandaentry[#{idx}]/question/simpara[normalize-space(text()) = 'Question #{idx}']", output, 1
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > answer", output, 1
        assert_css "qandaset > qandaentry:nth-child(#{idx}) > answer > simpara", output, 1
        assert_xpath "/qandaset/qandaentry[#{idx}]/answer/simpara[normalize-space(text()) = 'Answer #{idx}.']", output, 1
      end
      assert_xpath "/qandaset/qandaentry[2]/answer/simpara/following-sibling::note", output, 1
    end

    test 'consecutive questions should share same question element in docbook' do
      input = <<~'EOS'
      [qanda]
      question::
      follow-up question::
      response

      last question::
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_xpath '//qandaentry', output, 2
      assert_xpath '(//qandaentry)[1]/question', output, 1
      assert_xpath '(//qandaentry)[1]/question/simpara', output, 2
      assert_xpath '(//qandaentry)[2]/question', output, 1
      assert_xpath '(//qandaentry)[2]/answer', output, 1
      assert_xpath '(//qandaentry)[2]/answer[normalize-space(text())=""]', output, 1
    end

    test 'should convert bibliography list with proper semantics' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [bibliography]
      - [[[taoup]]] Eric Steven Raymond. _The Art of Unix
        Programming_. Addison-Wesley. ISBN 0-13-142901-9.
      - [[[walsh-muellner]]] Norman Walsh & Leonard Muellner.
        _DocBook - The Definitive Guide_. O'Reilly & Associates. 1999.
        ISBN 1-56592-580-7.
      EOS
      output = convert_string_to_embedded input
      assert_css '.ulist.bibliography', output, 1
      assert_css '.ulist.bibliography ul', output, 1
      assert_css '.ulist.bibliography ul li', output, 2
      assert_css '.ulist.bibliography ul li p', output, 2
      assert_css '.ulist.bibliography ul li:nth-child(1) p a#taoup', output, 1
      assert_xpath '//a/*', output, 0
      assert_xpath '(//a)[1][starts-with(following-sibling::text(), "[taoup] ")]', output, 1
    end

    test 'should convert bibliography list with proper semantics to DocBook' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [bibliography]
      - [[[taoup]]] Eric Steven Raymond. _The Art of Unix
        Programming_. Addison-Wesley. ISBN 0-13-142901-9.
      - [[[walsh-muellner]]] Norman Walsh & Leonard Muellner.
        _DocBook - The Definitive Guide_. O'Reilly & Associates. 1999.
        ISBN 1-56592-580-7.
      EOS
      output = convert_string_to_embedded input, backend: 'docbook'
      assert_css 'bibliodiv', output, 1
      assert_css 'bibliodiv > bibliomixed', output, 2
      assert_css 'bibliodiv > bibliomixed > bibliomisc', output, 2
      assert_css 'bibliodiv > bibliomixed:nth-child(1) > bibliomisc > anchor', output, 1
      assert_css 'bibliodiv > bibliomixed:nth-child(1) > bibliomisc > anchor[xreflabel="[taoup]"]', output, 1
      assert_xpath '(//bibliomixed)[1]/bibliomisc/anchor[starts-with(following-sibling::text(), "[taoup] Eric")]', output, 1
      assert_css 'bibliodiv > bibliomixed:nth-child(2) > bibliomisc > anchor', output, 1
      assert_css 'bibliodiv > bibliomixed:nth-child(2) > bibliomisc > anchor[xreflabel="[walsh-muellner]"]', output, 1
      assert_xpath '(//bibliomixed)[2]/bibliomisc/anchor[starts-with(following-sibling::text(), "[walsh-muellner] Norman")]', output, 1
    end

    test 'should warn if a bibliography ID is already in use' do
      input = <<~'EOS'
      [bibliography]
      * [[[Fowler]]] Fowler M. _Analysis Patterns: Reusable Object Models_.
      Addison-Wesley. 1997.
      * [[[Fowler]]] Fowler M. _Analysis Patterns: Reusable Object Models_.
      Addison-Wesley. 1997.
      EOS
      using_memory_logger do |logger|
        output = convert_string_to_embedded input
        assert_css '.ulist.bibliography', output, 1
        assert_css '.ulist.bibliography ul li:nth-child(1) p a#Fowler', output, 1
        assert_css '.ulist.bibliography ul li:nth-child(2) p a#Fowler', output, 1
        assert_message logger, :WARN, '<stdin>: line 4: id assigned to bibliography anchor already in use: Fowler', Hash
      end
    end

    test 'should automatically add bibliography style to top-level lists in bibliography section' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      [bibliography]
      == Bibliography

      .Books
      * [[[taoup]]] Eric Steven Raymond. _The Art of Unix
        Programming_. Addison-Wesley. ISBN 0-13-142901-9.
      * [[[walsh-muellner]]] Norman Walsh & Leonard Muellner.
        _DocBook - The Definitive Guide_. O'Reilly & Associates. 1999.
        ISBN 1-56592-580-7.

      .Periodicals
      * [[[doc-writer]]] Doc Writer. _Documentation As Code_. Static Times, 54. August 2016.
      EOS
      doc = document_from_string input
      ulists = doc.find_by context: :ulist
      assert_equal 2, ulists.size
      assert_equal ulists[0].style, 'bibliography'
      assert_equal ulists[1].style, 'bibliography'
    end

    test 'should not recognize bibliography anchor that begins with a digit' do
      input = <<~'EOS'
      [bibliography]
      - [[[1984]]] George Orwell. _1984_. New American Library. 1950.
      EOS

      output = convert_string_to_embedded input
      assert_includes output, '[[[1984]]]'
      assert_xpath '//a[@id="1984"]', output, 0
    end

    test 'should recognize bibliography anchor that contains a digit but does not start with one' do
      input = <<~'EOS'
      [bibliography]
      - [[[_1984]]] George Orwell. __1984__. New American Library. 1950.
      EOS

      output = convert_string_to_embedded input
      refute_includes output, '[[[_1984]]]'
      assert_includes output, '[_1984]'
      assert_xpath '//a[@id="_1984"]', output, 1
    end

    test 'should catalog bibliography anchors in bibliography list' do
      input = <<~'EOS'
      = Article Title

      Please read <<Fowler_1997>>.

      [bibliography]
      == References

      * [[[Fowler_1997]]] Fowler M. _Analysis Patterns: Reusable Object Models_. Addison-Wesley. 1997.
      EOS

      doc = document_from_string input
      assert doc.catalog[:refs].key? 'Fowler_1997'
    end

    test 'should use reftext from bibliography anchor at xref and entry' do
      input = <<~'EOS'
      = Article Title

      Begin with <<TMMM>>.
      Then move on to <<Fowler_1997>>.

      [bibliography]
      == References

      * [[[TMMM]]] Brooks F. _The Mythical Man-Month_. Addison-Wesley. 1975.
      * [[[Fowler_1997,1]]] Fowler M. _Analysis Patterns: Reusable Object Models_. Addison-Wesley. 1997.
      EOS

      doc = document_from_string input, standalone: false
      tmmm_ref = doc.catalog[:refs]['TMMM']
      refute_nil tmmm_ref
      assert_nil tmmm_ref.reftext
      fowler_1997_ref = doc.catalog[:refs]['Fowler_1997']
      refute_nil fowler_1997_ref
      assert_equal '[1]', fowler_1997_ref.reftext
      result = doc.convert standalone: false
      assert_xpath '//a[@href="#Fowler_1997"]', result, 1
      assert_xpath '//a[@href="#Fowler_1997"][text()="[1]"]', result, 1
      assert_xpath '//a[@id="Fowler_1997"]', result, 1
      assert_xpath '(//a[@id="Fowler_1997"])[1][starts-with(following-sibling::text(), "[1] ")]', result, 1
      assert_xpath '//a[@href="#TMMM"]', result, 1
      assert_xpath '//a[@href="#TMMM"][text()="[TMMM]"]', result, 1
      assert_xpath '//a[@id="TMMM"]', result, 1
      assert_xpath '(//a[@id="TMMM"])[1][starts-with(following-sibling::text(), "[TMMM] ")]', result, 1
    end

    test 'should assign reftext of bibliography anchor to xreflabel in DocBook backend' do
      input = <<~'EOS'
      [bibliography]
      * [[[Fowler_1997,1]]] Fowler M. _Analysis Patterns: Reusable Object Models_. Addison-Wesley. 1997.
      EOS

      result = convert_string_to_embedded input, backend: :docbook
      assert_includes result, '<anchor xml:id="Fowler_1997" xreflabel="[1]"/>[1] Fowler'
    end
  end
end

context 'Description lists redux' do

  context 'Label without text on same line' do

    test 'folds text from subsequent line' do
      input = <<~'EOS'
      == Lists

      term1::
      def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end

    test 'folds text from first line after blank lines' do
      input = <<~'EOS'
      == Lists

      term1::


      def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end

    test 'folds text from first line after blank line and immediately preceding next item' do
      input = <<~'EOS'
      == Lists

      term1::

      def1
      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="def1"]', output, 1
    end

    test 'paragraph offset by blank lines does not break list if label does not have inline text' do
      input = <<~'EOS'
      == Lists

      term1::

      def1

      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_css 'dl', output, 1
      assert_css 'dl > dt', output, 2
      assert_css 'dl > dd', output, 2
      assert_xpath '(//dl/dd)[1]/p[text()="def1"]', output, 1
    end

    test 'folds text from first line after comment line' do
      input = <<~'EOS'
      == Lists

      term1::
      // comment
      def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end

    test 'folds text from line following comment line offset by blank line' do
      input = <<~'EOS'
      == Lists

      term1::

      // comment
      def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end

    test 'folds text from subsequent indented line' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::
        def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end

    test 'folds text from indented line after blank line' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::

        def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
    end

    test 'folds text that looks like ruler offset by blank line' do
      input = <<~'EOS'
      == Lists

      term1::

      '''
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="'''"]), output, 1
    end

    test 'folds text that looks like ruler offset by blank line and line comment' do
      input = <<~'EOS'
      == Lists

      term1::

      // comment
      '''
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="'''"]), output, 1
    end

    test 'folds text that looks like ruler and the line following it offset by blank line' do
      input = <<~'EOS'
      == Lists

      term1::

      '''
      continued
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[normalize-space(text())="''' continued"]), output, 1
    end

    test 'folds text that looks like title offset by blank line' do
      input = <<~'EOS'
      == Lists

      term1::

      .def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()=".def1"]', output, 1
    end

    test 'folds text that looks like title offset by blank line and line comment' do
      input = <<~'EOS'
      == Lists

      term1::

      // comment
      .def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()=".def1"]', output, 1
    end

    test 'folds text that looks like admonition offset by blank line' do
      input = <<~'EOS'
      == Lists

      term1::

      NOTE: def1
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="NOTE: def1"]', output, 1
    end

    test 'folds text that looks like section title offset by blank line' do
      input = <<~'EOS'
      == Lists

      term1::

      == Another Section
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="== Another Section"]', output, 1
      assert_xpath '//h2', output, 1
    end

    test 'folds text of first literal line offset by blank line appends subsequent literals offset by blank line as blocks' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::

        def1

        literal


        literal
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 2
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 2
    end

    test 'folds text of subsequent line and appends following literal line offset by blank line as block if term has no inline description' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::
      def1

        literal

      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="def1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end

    test 'appends literal line attached by continuation as block if item has no inline description' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::
      +
        literal
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end

    test 'appends literal line attached by continuation as block if item has no inline description followed by ruler' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::
      +
        literal

      '''
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::hr', output, 1
    end

    test 'appends line attached by continuation as block if item has no inline description followed by ruler' do
      input = <<~'EOS'
      == Lists

      term1::
      +
      para

      '''
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::hr', output, 1
    end

    test 'appends line attached by continuation as block if item has no inline description followed by block' do
      input = <<~'EOS'
      == Lists

      term1::
      +
      para

      ....
      literal
      ....
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end

    test 'appends block attached by continuation but not subsequent block not attached by continuation' do
      input = <<~'EOS'
      == Lists

      term1::
      +
      ....
      literal
      ....
      ....
      detached
      ....
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="literalblock"]//pre[text()="detached"]', output, 1
    end

    test 'appends list if item has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::

      * one
      * two
      * three
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd//ul/li', output, 3
    end

    test 'appends list to first term when followed immediately by second term' do
      input = <<~'EOS'
      == Lists

      term1::

      * one
      * two
      * three
      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p', output, 0
      assert_xpath '(//*[@class="dlist"]//dd)[1]//ul/li', output, 3
      assert_xpath '(//*[@class="dlist"]//dd)[2]/p[text()="def2"]', output, 1
    end

    test 'appends indented list to first term that is adjacent to second term' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      label 1::
        description 1

        * one
        * two
        * three
      label 2::
        description 2

      paragraph
      EOS
      output = convert_string_to_embedded input
      assert_css '.dlist > dl', output, 1
      assert_css '.dlist dt', output, 2
      assert_xpath '(//*[@class="dlist"]//dt)[1][normalize-space(text())="label 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dt)[2][normalize-space(text())="label 2"]', output, 1
      assert_css '.dlist dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="description 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[2]/p[text()="description 2"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]//li', output, 3
      assert_css '.dlist + .paragraph', output, 1
    end

    test 'appends indented list to first term that is attached by a continuation and adjacent to second term' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      label 1::
        description 1
      +
        * one
        * two
        * three
      label 2::
        description 2

      paragraph
      EOS
      output = convert_string_to_embedded input
      assert_css '.dlist > dl', output, 1
      assert_css '.dlist dt', output, 2
      assert_xpath '(//*[@class="dlist"]//dt)[1][normalize-space(text())="label 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dt)[2][normalize-space(text())="label 2"]', output, 1
      assert_css '.dlist dd', output, 2
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p[text()="description 1"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[2]/p[text()="description 2"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]', output, 1
      assert_xpath '(//*[@class="dlist"]//dd)[1]/p/following-sibling::*[@class="ulist"]//li', output, 3
      assert_css '.dlist + .paragraph', output, 1
    end

    test 'appends list and paragraph block when line following list attached by continuation' do
      input = <<~'EOS'
      == Lists

      term1::

      * one
      * two
      * three

      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/ul/li', output, 3
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'first continued line associated with nested list item and second continued line associated with term' do
      input = <<~'EOS'
      == Lists

      term1::
      * one
      +
      nested list para

      +
      term1 para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/ul/li', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/ul/li/*[@class="paragraph"]/p[text()="nested list para"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="ulist"]/following-sibling::*[@class="paragraph"]/p[text()="term1 para"]', output, 1
    end

    test 'literal line attached by continuation swallows adjacent line that looks like term' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1::
      +
        literal
      notnestedterm:::
      +
        literal
      notnestedterm:::
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]', output, 2
      assert_xpath %(//*[@class="dlist"]//dd/*[@class="literalblock"]//pre[text()="  literal\nnotnestedterm:::"]), output, 2
    end

    test 'line attached by continuation is appended as paragraph if term has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::
      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'attached paragraph does not break on adjacent nested description list term' do
      input = <<~'EOS'
      term1:: def
      +
      more description
      not a term::: def
      EOS

      output = convert_string_to_embedded input
      assert_css '.dlist > dl > dt', output, 1
      assert_css '.dlist > dl > dd', output, 1
      assert_css '.dlist > dl > dd > .paragraph', output, 1
      assert_includes output, 'not a term::: def'
    end

    # FIXME this is a negative test; the behavior should be the other way around
    test 'attached paragraph is terminated by adjacent sibling description list term' do
      input = <<~'EOS'
      term1:: def
      +
      more description
      not a term:: def
      EOS

      output = convert_string_to_embedded input
      assert_css '.dlist > dl > dt', output, 2
      assert_css '.dlist > dl > dd', output, 2
      assert_css '.dlist > dl > dd > .paragraph', output, 1
      refute_includes output, 'not a term:: def'
    end

    test 'attached styled paragraph does not break on adjacent nested description list term' do
      input = <<~'EOS'
      term1:: def
      +
      [quote]
      more description
      not a term::: def
      EOS

      output = convert_string_to_embedded input
      assert_css '.dlist > dl > dt', output, 1
      assert_css '.dlist > dl > dd', output, 1
      assert_css '.dlist > dl > dd > .quoteblock', output, 1
      assert_includes output, 'not a term::: def'
    end

    test 'appends line as paragraph if attached by continuation following blank line and line comment when term has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::

      // comment
      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'line attached by continuation offset by blank line is appended as paragraph if term has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::

      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p', output, 0
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'delimited block breaks list even when term has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::
      ====
      detached
      ====
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 0
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="exampleblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="exampleblock"]//p[text()="detached"]', output, 1
    end

    test 'block attribute line above delimited block that breaks a dlist is not duplicated' do
      input = <<~'EOS'
      == Lists

      term:: desc
      [.rolename]
      ----
      detached
      ----
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="listingblock rolename"]', output, 1
    end

    test 'block attribute line above paragraph breaks list even when term has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::
      [verse]
      detached
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 0
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="verseblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="verseblock"]/pre[text()="detached"]', output, 1
    end

    test 'block attribute line above paragraph that breaks a dlist is not duplicated' do
      input = <<~'EOS'
      == Lists

      term:: desc
      [.rolename]
      detached
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph rolename"]', output, 1
    end

    test 'block anchor line breaks list even when term has no inline description' do
      input = <<~'EOS'
      == Lists

      term1::
      [[id]]
      detached
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 0
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]/p[text()="detached"]', output, 1
    end

    test 'block attribute lines above nested horizontal list does not break list' do
      input = <<~'EOS'
      Operating Systems::
      [horizontal]
        Linux::: Fedora
        BSD::: OpenBSD

      Cloud Providers::
        PaaS::: OpenShift
        IaaS::: AWS
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 2
      assert_xpath '/*[@class="dlist"]/dl', output, 1
      assert_xpath '(//dl)[1]/dd', output, 2
      assert_xpath '((//dl)[1]/dd)[1]//table', output, 1
      assert_xpath '((//dl)[1]/dd)[2]//table', output, 0
    end

    test 'block attribute lines above nested list with style does not break list' do
      input = <<~'EOS'
      TODO List::
      * get groceries
      Grocery List::
      [square]
      * bread
      * milk
      * lettuce
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 1
      assert_xpath '(//dl)[1]/dd', output, 2
      assert_xpath '((//dl)[1]/dd)[2]//ul[@class="square"]', output, 1
    end

    test 'multiple block attribute lines above nested list does not break list' do
      input = <<~'EOS'
      Operating Systems::
      [[variants]]
      [horizontal]
        Linux::: Fedora
        BSD::: OpenBSD

      Cloud Providers::
        PaaS::: OpenShift
        IaaS::: AWS
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 2
      assert_xpath '/*[@class="dlist"]/dl', output, 1
      assert_xpath '(//dl)[1]/dd', output, 2
      assert_xpath '(//dl)[1]/dd/*[@id="variants"]', output, 1
      assert_xpath '((//dl)[1]/dd)[1]//table', output, 1
      assert_xpath '((//dl)[1]/dd)[2]//table', output, 0
    end

    test 'multiple block attribute lines separated by empty line above nested list does not break list' do
      input = <<~'EOS'
      Operating Systems::
      [[variants]]

      [horizontal]

        Linux::: Fedora
        BSD::: OpenBSD

      Cloud Providers::
        PaaS::: OpenShift
        IaaS::: AWS
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//dl', output, 2
      assert_xpath '/*[@class="dlist"]/dl', output, 1
      assert_xpath '(//dl)[1]/dd', output, 2
      assert_xpath '(//dl)[1]/dd/*[@id="variants"]', output, 1
      assert_xpath '((//dl)[1]/dd)[1]//table', output, 1
      assert_xpath '((//dl)[1]/dd)[2]//table', output, 0
    end
  end

  context 'Item with text inline' do

    test 'folds text from inline description and subsequent line' do
      input = <<~'EOS'
      == Lists

      term1:: def1
      continued
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued"]), output, 1
    end

    test 'folds text from inline description and subsequent lines' do
      input = <<~'EOS'
      == Lists

      term1:: def1
      continued
      continued
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued\ncontinued"]), output, 1
    end

    test 'folds text from inline description and line following comment line' do
      input = <<~'EOS'
      == Lists

      term1:: def1
      // comment
      continued
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued"]), output, 1
    end

    test 'folds text from inline description and subsequent indented line' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == List

      term1:: def1
        continued
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath %(//*[@class="dlist"]//dd/p[text()="def1\ncontinued"]), output, 1
    end

    test 'appends literal line offset by blank line as block if item has inline description' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1:: def1

        literal
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end

    test 'appends literal line offset by blank line as block and appends line after continuation as block if item has inline description' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1:: def1

        literal
      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="literalblock"]/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'appends line after continuation as block and literal line offset by blank line as block if item has inline description' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1:: def1
      +
      para

        literal
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/*[@class="paragraph"]/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
    end

    test 'appends list if item has inline description' do
      input = <<~'EOS'
      == Lists

      term1:: def1

      * one
      * two
      * three
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="ulist"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="ulist"]/ul/li', output, 3
    end

    test 'appends literal line attached by continuation as block if item has inline description followed by ruler' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term1:: def1
      +
        literal

      '''
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="literalblock"]//pre[text()="literal"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::hr', output, 1
    end

    test 'line offset by blank line breaks list if term has inline description' do
      input = <<~'EOS'
      == Lists

      term1:: def1

      detached
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]/p[text()="detached"]', output, 1
    end

    test 'nested term with description does not consume following heading' do
      # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
      input = <<~EOS
      == Lists

      term::
        def
        nestedterm;;
          nesteddef

      Detached
      ~~~~~~~~
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
      assert_xpath '//*[@class="dlist"]//dd', output, 2
      assert_xpath '//*[@class="dlist"]/dl//dl', output, 1
      assert_xpath '//*[@class="dlist"]/dl//dl/dt', output, 1
      assert_xpath '((//*[@class="dlist"])[1]//dd)[1]/p[text()="def"]', output, 1
      assert_xpath '((//*[@class="dlist"])[1]//dd)[1]/p/following-sibling::*[@class="dlist"]', output, 1
      assert_xpath '((//*[@class="dlist"])[1]//dd)[1]/p/following-sibling::*[@class="dlist"]//dd/p[text()="nesteddef"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sect2"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sect2"]/h3[text()="Detached"]', output, 1
    end

    test 'line attached by continuation is appended as paragraph if term has inline description followed by detached paragraph' do
      input = <<~'EOS'
      == Lists

      term1:: def1
      +
      para

      detached
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="paragraph"]/p[text()="detached"]', output, 1
    end

    test 'line attached by continuation is appended as paragraph if term has inline description followed by detached block' do
      input = <<~'EOS'
      == Lists

      term1:: def1
      +
      para

      ****
      detached
      ****
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sidebarblock"]', output, 1
      assert_xpath '//*[@class="dlist"]/following-sibling::*[@class="sidebarblock"]//p[text()="detached"]', output, 1
    end

    test 'line attached by continuation offset by line comment is appended as paragraph if term has inline description' do
      input = <<~'EOS'
      == Lists

      term1:: def1
      // comment
      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'line attached by continuation offset by blank line is appended as paragraph if term has inline description' do
      input = <<~'EOS'
      == Lists

      term1:: def1

      +
      para
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 1
      assert_xpath '//*[@class="dlist"]//dd', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p[text()="def1"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="dlist"]//dd/p/following-sibling::*[@class="paragraph"]/p[text()="para"]', output, 1
    end

    test 'line comment offset by blank line divides lists because item has text' do
      input = <<~'EOS'
      == Lists

      term1:: def1

      //

      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
    end

    test 'ruler offset by blank line divides lists because item has text' do
      input = <<~'EOS'
      == Lists

      term1:: def1

      '''

      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
    end

    test 'block title offset by blank line divides lists and becomes title of second list because item has text' do
      input = <<~'EOS'
      == Lists

      term1:: def1

      .title

      term2:: def2
      EOS

      output = convert_string_to_embedded input
      assert_xpath '//*[@class="dlist"]/dl', output, 2
      assert_xpath '(//*[@class="dlist"])[2]/*[@class="title"][text()="title"]', output, 1
    end
  end
end

context 'Callout lists' do
  test 'does not recognize callout list denoted by markers that only have a trailing bracket' do
    input = <<~'EOS'
    ----
    require 'asciidoctor' # <1>
    ----
    1> Not a callout list item
    EOS

    output = convert_string_to_embedded input
    assert_css '.colist', output, 0
  end

  test 'should not hang if obsolete callout list is found inside list item' do
    input = <<~'EOS'
    * foo
    1> bar
    EOS

    output = convert_string_to_embedded input
    assert_css '.colist', output, 0
  end

  test 'should not hang if obsolete callout list is found inside dlist item' do
    input = <<~'EOS'
    foo::
    1> bar
    EOS

    output = convert_string_to_embedded input
    assert_css '.colist', output, 0
  end

  test 'should recognize auto-numberd callout list inside list' do
    input = <<~'EOS'
    ----
    require 'asciidoctor' # <1>
    ----
    * foo
    <.> bar
    EOS

    output = convert_string_to_embedded input
    assert_css '.colist', output, 1
  end

  test 'listing block with sequential callouts followed by adjacent callout list' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <3>
    ----
    <1> Describe the first line
    <2> Describe the second line
    <3> Describe the third line
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@xml:id="CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@xml:id="CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@xml:id="CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 3
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-2"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[3][@arearefs = "CO1-3"]', output, 1
  end

  test 'listing block with sequential callouts followed by non-adjacent callout list' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <3>
    ----

    Paragraph.

    <1> Describe the first line
    <2> Describe the second line
    <3> Describe the third line
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@xml:id="CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@xml:id="CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@xml:id="CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::*[1][self::simpara]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 3
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-2"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[3][@arearefs = "CO1-3"]', output, 1
  end

  test 'listing block with a callout that refers to two different lines' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <2>
    ----
    <1> Import the library
    <2> Where the magic happens
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@xml:id="CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@xml:id="CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@xml:id="CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 2
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-2 CO1-3"]', output, 1
  end

  test 'source block with non-sequential callouts followed by adjacent callout list' do
    input = <<~'EOS'
    [source,ruby]
    ----
    require 'asciidoctor' # <2>
    doc = Asciidoctor::Document.new('Hello, World!') # <3>
    puts doc.convert # <1>
    ----
    <1> Describe the first line
    <2> Describe the second line
    <3> Describe the third line
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//programlisting', output, 1
    assert_xpath '//programlisting//co', output, 3
    assert_xpath '(//programlisting//co)[1][@xml:id="CO1-1"]', output, 1
    assert_xpath '(//programlisting//co)[2][@xml:id="CO1-2"]', output, 1
    assert_xpath '(//programlisting//co)[3][@xml:id="CO1-3"]', output, 1
    assert_xpath '//programlisting/following-sibling::calloutlist/callout', output, 3
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[1][@arearefs = "CO1-3"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[2][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//programlisting/following-sibling::calloutlist/callout)[3][@arearefs = "CO1-2"]', output, 1
  end

  test 'two listing blocks can share the same callout list' do
    input = <<~'EOS'
    .Import library
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    ----

    .Use library
    [source, ruby]
    ----
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <3>
    ----

    <1> Describe the first line
    <2> Describe the second line
    <3> Describe the third line
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//programlisting', output, 2
    assert_xpath '(//programlisting)[1]//co', output, 1
    assert_xpath '(//programlisting)[1]//co[@xml:id="CO1-1"]', output, 1
    assert_xpath '(//programlisting)[2]//co', output, 2
    assert_xpath '((//programlisting)[2]//co)[1][@xml:id="CO1-2"]', output, 1
    assert_xpath '((//programlisting)[2]//co)[2][@xml:id="CO1-3"]', output, 1
    assert_xpath '(//calloutlist/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//calloutlist/callout)[2][@arearefs = "CO1-2"]', output, 1
    assert_xpath '(//calloutlist/callout)[3][@arearefs = "CO1-3"]', output, 1
  end

  test 'two listing blocks each followed by an adjacent callout list' do
    input = <<~'EOS'
    .Import library
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    ----
    <1> Describe the first line

    .Use library
    [source, ruby]
    ----
    doc = Asciidoctor::Document.new('Hello, World!') # <1>
    puts doc.convert # <2>
    ----
    <1> Describe the second line
    <2> Describe the third line
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//programlisting', output, 2
    assert_xpath '(//programlisting)[1]//co', output, 1
    assert_xpath '(//programlisting)[1]//co[@xml:id="CO1-1"]', output, 1
    assert_xpath '(//programlisting)[2]//co', output, 2
    assert_xpath '((//programlisting)[2]//co)[1][@xml:id="CO2-1"]', output, 1
    assert_xpath '((//programlisting)[2]//co)[2][@xml:id="CO2-2"]', output, 1
    assert_xpath '//calloutlist', output, 2
    assert_xpath '(//calloutlist)[1]/callout', output, 1
    assert_xpath '((//calloutlist)[1]/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//calloutlist)[2]/callout', output, 2
    assert_xpath '((//calloutlist)[2]/callout)[1][@arearefs = "CO2-1"]', output, 1
    assert_xpath '((//calloutlist)[2]/callout)[2][@arearefs = "CO2-2"]', output, 1
  end

  test 'callout list retains block content' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <3>
    ----
    <1> Imports the library
    as a RubyGem
    <2> Creates a new document
    * Scans the lines for known blocks
    * Converts the lines into blocks
    <3> Renders the document
    +
    You can write this to file rather than printing to stdout.
    EOS
    output = convert_string_to_embedded input
    assert_xpath '//ol/li', output, 3
    assert_xpath %((//ol/li)[1]/p[text()="Imports the library\nas a RubyGem"]), output, 1
    assert_xpath %((//ol/li)[2]//ul), output, 1
    assert_xpath %((//ol/li)[2]//ul/li), output, 2
    assert_xpath %((//ol/li)[3]//p), output, 2
  end

  test 'callout list retains block content when converted to DocBook' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <3>
    ----
    <1> Imports the library
    as a RubyGem
    <2> Creates a new document
    * Scans the lines for known blocks
    * Converts the lines into blocks
    <3> Renders the document
    +
    You can write this to file rather than printing to stdout.
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//calloutlist', output, 1
    assert_xpath '//calloutlist/callout', output, 3
    assert_xpath '(//calloutlist/callout)[1]/*', output, 1
    assert_xpath '(//calloutlist/callout)[2]/para', output, 1
    assert_xpath '(//calloutlist/callout)[2]/itemizedlist', output, 1
    assert_xpath '(//calloutlist/callout)[3]/para', output, 1
    assert_xpath '(//calloutlist/callout)[3]/simpara', output, 1
  end

  test 'escaped callout should not be interpreted as a callout' do
    input = <<~'EOS'
    [source,text]
    ----
    require 'asciidoctor' # \<1>
    Asciidoctor.convert 'convert me!' \<2>
    ----
    EOS
    [{}, { 'source-highlighter' => 'coderay' }].each do |attributes|
      output = convert_string_to_embedded input, attributes: attributes
      assert_css 'pre b', output, 0
      assert_includes output, ' # &lt;1&gt;'
      assert_includes output, ' &lt;2&gt;'
    end
  end

  test 'should autonumber <.> callouts' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <.>
    doc = Asciidoctor::Document.new('Hello, World!') # <.>
    puts doc.convert # <.>
    ----
    <.> Describe the first line
    <.> Describe the second line
    <.> Describe the third line
    EOS
    output = convert_string_to_embedded input
    pre_html = (xmlnodes_at_css 'pre', output)[0].inner_html
    assert_includes pre_html, '(1)'
    assert_includes pre_html, '(2)'
    assert_includes pre_html, '(3)'
    assert_css '.colist ol', output, 1
    assert_css '.colist ol li', output, 3
  end

  test 'should not recognize callouts in middle of line' do
    input = <<~'EOS'
    [source, ruby]
    ----
    puts "The syntax <1> at the end of the line makes a code callout"
    ----
    EOS
    output = convert_string_to_embedded input
    assert_xpath '//b', output, 0
  end

  test 'should allow multiple callouts on the same line' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' <1>
    doc = Asciidoctor.load('Hello, World!') # <2> <3> <4>
    puts doc.convert <5><6>
    exit 0
    ----
    <1> Require library
    <2> Load document from String
    <3> Uses default backend and doctype
    <4> One more for good luck
    <5> Renders document to String
    <6> Prints output to stdout
    EOS
    output = convert_string_to_embedded input
    assert_xpath '//code/b', output, 6
    assert_match(/ <b class="conum">\(1\)<\/b>$/, output)
    assert_match(/ <b class="conum">\(2\)<\/b> <b class="conum">\(3\)<\/b> <b class="conum">\(4\)<\/b>$/, output)
    assert_match(/ <b class="conum">\(5\)<\/b><b class="conum">\(6\)<\/b>$/, output)
  end

  test 'should allow XML comment-style callouts' do
    input = <<~'EOS'
    [source, xml]
    ----
    <section>
      <title>Section Title</title> <!--1-->
      <simpara>Just a paragraph</simpara> <!--2-->
    </section>
    ----
    <1> The title is required
    <2> The content isn't
    EOS
    output = convert_string_to_embedded input
    assert_xpath '//b', output, 2
    assert_xpath '//b[text()="(1)"]', output, 1
    assert_xpath '//b[text()="(2)"]', output, 1
  end

  test 'should not allow callouts with half an XML comment' do
    input = <<~'EOS'
    ----
    First line <1-->
    Second line <2-->
    ----
    EOS
    output = convert_string_to_embedded input
    assert_xpath '//b', output, 0
  end

  test 'should not recognize callouts in an indented description list paragraph' do
    # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
    input = <<~EOS
    foo::
      bar <1>

    <1> Not pointing to a callout
    EOS
    using_memory_logger do |logger|
      output = convert_string_to_embedded input
      assert_xpath '//dl//b', output, 0
      assert_xpath '//dl/dd/p[text()="bar <1>"]', output, 1
      assert_xpath '//ol/li/p[text()="Not pointing to a callout"]', output, 1
      assert_message logger, :WARN, '<stdin>: line 4: no callout found for <1>', Hash
    end
  end

  test 'should not recognize callouts in an indented outline list paragraph' do
    # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
    input = <<~EOS
    * foo
      bar <1>

    <1> Not pointing to a callout
    EOS
    using_memory_logger do |logger|
      output = convert_string_to_embedded input
      assert_xpath '//ul//b', output, 0
      assert_xpath %(//ul/li/p[text()="foo\nbar <1>"]), output, 1
      assert_xpath '//ol/li/p[text()="Not pointing to a callout"]', output, 1
      assert_message logger, :WARN, '<stdin>: line 4: no callout found for <1>', Hash
    end
  end

  test 'should warn if numbers in callout list are out of sequence' do
    input = <<~'EOS'
    ----
    <beans> <1>
      <bean class="com.example.HelloWorld"/>
    </beans>
    ----
    <1> Container of beans.
    Beans are fun.
    <3> An actual bean.
    EOS
    using_memory_logger do |logger|
      output = convert_string_to_embedded input
      assert_xpath '//ol/li', output, 2
      assert_messages logger, [
        [:WARN, '<stdin>: line 8: callout list item index: expected 2, got 3', Hash],
        [:WARN, '<stdin>: line 8: no callout found for <2>', Hash]
      ]
    end
  end

  test 'should preserve line comment chars that precede callout number if icons is not set' do
    input = <<~'EOS'
    [source,ruby]
    ----
    puts 'Hello, world!' # <1>
    ----
    <1> Ruby

    [source,groovy]
    ----
    println 'Hello, world!' // <1>
    ----
    <1> Groovy

    [source,clojure]
    ----
    (def hello (fn [] "Hello, world!")) ;; <1>
    (hello)
    ----
    <1> Clojure

    [source,haskell]
    ----
    main = putStrLn "Hello, World!" -- <1>
    ----
    <1> Haskell
    EOS
    [{}, { 'source-highlighter' => 'coderay' }].each do |attributes|
      output = convert_string_to_embedded input, attributes: attributes
      assert_xpath '//b', output, 4
      nodes = xmlnodes_at_css 'pre', output
      assert_equal %(puts 'Hello, world!' # (1)), nodes[0].text
      assert_equal %(println 'Hello, world!' // (1)), nodes[1].text
      assert_equal %((def hello (fn [] "Hello, world!")) ;; (1)\n(hello)), nodes[2].text
      assert_equal %(main = putStrLn "Hello, World!" -- (1)), nodes[3].text
    end
  end

  test 'should remove line comment chars that precede callout number if icons is font' do
    input = <<~'EOS'
    [source,ruby]
    ----
    puts 'Hello, world!' # <1>
    ----
    <1> Ruby

    [source,groovy]
    ----
    println 'Hello, world!' // <1>
    ----
    <1> Groovy

    [source,clojure]
    ----
    (def hello (fn [] "Hello, world!")) ;; <1>
    (hello)
    ----
    <1> Clojure

    [source,haskell]
    ----
    main = putStrLn "Hello, World!" -- <1>
    ----
    <1> Haskell
    EOS
    [{}, { 'source-highlighter' => 'coderay' }].each do |attributes|
      output = convert_string_to_embedded input, attributes: attributes.merge({ 'icons' => 'font' })
      assert_css 'pre b', output, 4
      assert_css 'pre i.conum', output, 4
      nodes = xmlnodes_at_css 'pre', output
      assert_equal %(puts 'Hello, world!' (1)), nodes[0].text
      assert_equal %(println 'Hello, world!' (1)), nodes[1].text
      assert_equal %((def hello (fn [] "Hello, world!")) (1)\n(hello)), nodes[2].text
      assert_equal %(main = putStrLn "Hello, World!" (1)), nodes[3].text
    end
  end

  test 'should allow line comment chars that precede callout number to be specified' do
    # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
    input = <<~EOS
    [source,erlang,line-comment=%]
    ----
    hello_world() -> % <1>
      io:fwrite("hello, world~n"). %<2>
    ----
    <1> Erlang function clause head.
    <2> ~n adds a new line to the output.
    EOS
    output = convert_string_to_embedded input
    assert_xpath '//b', output, 2
    nodes = xmlnodes_at_css 'pre', output
    assert_equal %(hello_world() -> % (1)\n  io:fwrite("hello, world~n"). %(2)), nodes[0].text
  end

  test 'should allow line comment chars preceding callout number to be configurable when source-highlighter is coderay' do
    input = <<~'EOS'
    [source,html,line-comment=-#]
    ----
    -# <1>
    %p Hello
    ----
    <1> Prints a paragraph with the text "Hello"
    EOS
    output = convert_string_to_embedded input, attributes: { 'source-highlighter' => 'coderay' }
    assert_xpath '//b', output, 1
    nodes = xmlnodes_at_css 'pre', output
    assert_equal %(-# (1)\n%p Hello), nodes[0].text
  end

  test 'should not eat whitespace before callout number if line-comment attribute is empty' do
    input = <<~'EOS'
    [source,asciidoc,line-comment=]
    ----
    -- <1>
    ----
    <1> The start of an open block.
    EOS
    output = convert_string_to_embedded input, attributes: { 'icons' => 'font' }
    assert_includes output, '-- <i class="conum"'
  end

  test 'literal block with callouts' do
    input = <<~'EOS'
    ....
    Roses are red <1>
    Violets are blue <2>
    ....


    <1> And so is Ruby
    <2> But violet is more like purple
    EOS
    output = convert_string input, attributes: { 'backend' => 'docbook' }
    assert_xpath '//literallayout', output, 1
    assert_xpath '//literallayout//co', output, 2
    assert_xpath '(//literallayout//co)[1][@xml:id="CO1-1"]', output, 1
    assert_xpath '(//literallayout//co)[2][@xml:id="CO1-2"]', output, 1
    assert_xpath '//literallayout/following-sibling::*[1][self::calloutlist]/callout', output, 2
    assert_xpath '(//literallayout/following-sibling::*[1][self::calloutlist]/callout)[1][@arearefs = "CO1-1"]', output, 1
    assert_xpath '(//literallayout/following-sibling::*[1][self::calloutlist]/callout)[2][@arearefs = "CO1-2"]', output, 1
  end

  test 'callout list with icons enabled' do
    input = <<~'EOS'
    [source, ruby]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') # <2>
    puts doc.convert # <3>
    ----
    <1> Describe the first line
    <2> Describe the second line
    <3> Describe the third line
    EOS
    output = convert_string_to_embedded input, attributes: { 'icons' => '' }
    assert_css '.listingblock code > img', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="listingblock"]//code/img)[#{i}][@src="./images/icons/callouts/#{i}.png"][@alt="#{i}"]), output, 1
    end
    assert_css '.colist table td img', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="colist arabic"]//td/img)[#{i}][@src="./images/icons/callouts/#{i}.png"][@alt="#{i}"]), output, 1
    end
  end

  test 'callout list with font-based icons enabled' do
    input = <<~'EOS'
    [source]
    ----
    require 'asciidoctor' # <1>
    doc = Asciidoctor::Document.new('Hello, World!') #<2>
    puts doc.convert #<3>
    ----
    <1> Describe the first line
    <2> Describe the second line
    <3> Describe the third line
    EOS
    output = convert_string_to_embedded input, attributes: { 'icons' => 'font' }
    assert_css '.listingblock code > i', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="listingblock"]//code/i)[#{i}]), output, 1
      assert_xpath %((/div[@class="listingblock"]//code/i)[#{i}][@class="conum"][@data-value="#{i}"]), output, 1
      assert_xpath %((/div[@class="listingblock"]//code/i)[#{i}]/following-sibling::b[text()="(#{i})"]), output, 1
    end
    assert_css '.colist table td i', output, 3
    (1..3).each do |i|
      assert_xpath %((/div[@class="colist arabic"]//td/i)[#{i}]), output, 1
      assert_xpath %((/div[@class="colist arabic"]//td/i)[#{i}][@class="conum"][@data-value = "#{i}"]), output, 1
      assert_xpath %((/div[@class="colist arabic"]//td/i)[#{i}]/following-sibling::b[text() = "#{i}"]), output, 1
    end
  end

  test 'should match trailing line separator in text of list item' do
    input = <<~EOS.chop
    ----
    A <1>
    B <2>
    C <3>
    ----
    <1> a
    <2> b#{decode_char 8232}
    <3> c
    EOS

    output = convert_string input
    assert_css 'li', output, 3
    assert_xpath %((//li)[2]/p[text()="b#{decode_char 8232}"]), output, 1
  end

  test 'should match line separator in text of list item' do
    input = <<~EOS.chop
    ----
    A <1>
    B <2>
    C <3>
    ----
    <1> a
    <2> b#{decode_char 8232}b
    <3> c
    EOS

    output = convert_string input
    assert_css 'li', output, 3
    assert_xpath %((//li)[2]/p[text()="b#{decode_char 8232}b"]), output, 1
  end
end

context 'Checklists' do
  test 'should create checklist if at least one item has checkbox syntax' do
    input = <<~'EOS'
    - [ ] todo
    - [x] done
    - [ ] another todo
    - [*] another done
    - plain
    EOS

    doc = document_from_string input
    checklist = doc.blocks[0]
    assert checklist.option?('checklist')
    assert checklist.items[0].attr?('checkbox')
    refute checklist.items[0].attr?('checked')
    assert checklist.items[1].attr?('checkbox')
    assert checklist.items[1].attr?('checked')
    refute checklist.items[4].attr?('checkbox')

    output = doc.convert standalone: false
    assert_css '.ulist.checklist', output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[1]/p[text()="#{decode_char 10063} todo"]), output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[2]/p[text()="#{decode_char 10003} done"]), output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[3]/p[text()="#{decode_char 10063} another todo"]), output, 1
    assert_xpath %((/*[@class="ulist checklist"]/ul/li)[4]/p[text()="#{decode_char 10003} another done"]), output, 1
    assert_xpath '(/*[@class="ulist checklist"]/ul/li)[5]/p[text()="plain"]', output, 1
  end

  test 'entry is not a checklist item if the closing bracket is not immediately followed by the space character' do
    input = <<~EOS
    - [ ]    todo
    - [x] \t done
    - [ ]\t  another todo
    - [x]\t  another done
    EOS
    doc = document_from_string input
    checklist = doc.blocks[0]
    assert checklist.option?('checklist')
    assert checklist.items[0].attr?('checkbox')
    refute checklist.items[0].attr?('checked')
    assert checklist.items[1].attr?('checkbox')
    assert checklist.items[1].attr?('checked')
    refute checklist.items[2].attr?('checkbox')
    refute checklist.items[3].attr?('checkbox')
  end

  test 'should create checklist with font icons if at least one item has checkbox syntax and icons attribute is font' do
    input = <<~'EOS'
    - [ ] todo
    - [x] done
    - plain
    EOS

    output = convert_string_to_embedded input, attributes: { 'icons' => 'font' }
    assert_css '.ulist.checklist', output, 1
    assert_css '.ulist.checklist li i.fa-check-square-o', output, 1
    assert_css '.ulist.checklist li i.fa-square-o', output, 1
    assert_xpath '(/*[@class="ulist checklist"]/ul/li)[3]/p[text()="plain"]', output, 1
  end

  test 'should create interactive checklist if interactive option is set even with icons attribute is font' do
    input = <<~'EOS'
    :icons: font

    [%interactive]
    - [ ] todo
    - [x] done
    EOS

    doc = document_from_string input
    checklist = doc.blocks[0]
    assert checklist.option?('checklist')
    assert checklist.option?('interactive')

    output = doc.convert standalone: false
    assert_css '.ulist.checklist', output, 1
    assert_css '.ulist.checklist li input[type="checkbox"]', output, 2
    assert_css '.ulist.checklist li input[type="checkbox"][disabled]', output, 0
    assert_css '.ulist.checklist li input[type="checkbox"][checked]', output, 1
  end

  test 'should not create checklist if checkbox on item is followed by a tab' do
    ['[ ]', '[x]', '[*]'].each do |checkbox|
      input = <<~EOS
      - #{checkbox}\ttodo
      EOS

      doc = document_from_string input
      list = doc.blocks[0]
      assert_equal :ulist, list.context
      refute list.option?('checklist')
    end
  end
end

context 'Lists model' do
  test 'content should return items in list' do
    input = <<~'EOS'
    * one
    * two
    * three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    assert_kind_of Asciidoctor::List, list
    items = list.items
    assert_equal 3, items.size
    assert_equal list.items, list.content
  end

  test 'list item should be the parent of block attached to a list item' do
    input = <<~'EOS'
    * list item 1
    +
    ----
    listing block in list item 1
    ----
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    list_item_1 = list.items.first
    listing_block = list_item_1.blocks.first
    assert_equal :listing, listing_block.context
    assert_equal list_item_1, listing_block.parent
  end

  test 'outline? should return true for unordered list' do
    input = <<~'EOS'
    * one
    * two
    * three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    assert list.outline?
  end

  test 'outline? should return true for ordered list' do
    input = <<~'EOS'
    . one
    . two
    . three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    assert list.outline?
  end

  test 'outline? should return false for description list' do
    input = 'label:: desc'
    doc = document_from_string input
    list = doc.blocks.first
    refute list.outline?
  end

  test 'simple? should return true for list item with no nested blocks' do
    input = <<~'EOS'
    * one
    * two
    * three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    assert list.items.first.simple?
    refute list.items.first.compound?
  end

  test 'simple? should return true for list item with nested outline list' do
    # NOTE cannot use single-quoted heredoc because of https://github.com/jruby/jruby/issues/4260
    input = <<~EOS
    * one
      ** more about one
      ** and more
    * two
    * three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    assert list.items.first.simple?
    refute list.items.first.compound?
  end

  test 'simple? should return false for list item with block content' do
    input = <<~'EOS'
    * one
    +
    ----
    listing block in list item 1
    ----
    * two
    * three
    EOS

    doc = document_from_string input
    list = doc.blocks.first
    refute list.items.first.simple?
    assert list.items.first.compound?
  end

  test 'should allow text of ListItem to be assigned' do
    input = <<~'EOS'
    * one
    * two
    * three
    EOS

    doc = document_from_string input
    list = (doc.find_by context: :ulist).first
    assert_equal 3, list.items.size
    assert_equal 'one', list.items[0].text
    list.items[0].text = 'un'
    assert_equal 'un', list.items[0].text
  end

  test 'id and role assigned to ulist item in model are transmitted to output' do
    input = <<~'EOS'
		* one
		* two
		* three
    EOS

    doc = document_from_string input
    item_0 = doc.blocks[0].items[0]
    item_0.id = 'one'
    item_0.add_role 'item'
    output = doc.convert
    assert_css 'li#one.item', output, 1
  end

  test 'id and role assigned to olist item in model are transmitted to output' do
    input = <<~'EOS'
    . one
    . two
    . three
    EOS

    doc = document_from_string input
    item_0 = doc.blocks[0].items[0]
    item_0.id = 'one'
    item_0.add_role 'item'
    output = doc.convert
    assert_css 'li#one.item', output, 1
  end

  test 'should allow API control over substitutions applied to ListItem text' do
    input = <<~'EOS'
    * *one*
    * _two_
    * `three`
    * #four#
    EOS

    doc = document_from_string input
    list = (doc.find_by context: :ulist).first
    assert_equal 4, list.items.size
    list.items[0].remove_sub :quotes
    assert_equal '*one*', list.items[0].text
    refute_includes list.items[0].subs, :quotes
    list.items[1].subs.clear
    assert_empty list.items[1].subs
    assert_equal '_two_', list.items[1].text
    list.items[2].subs.replace [:specialcharacters]
    assert_equal [:specialcharacters], list.items[2].subs
    assert_equal '`three`', list.items[2].text
    assert_equal '<mark>four</mark>', list.items[3].text
  end

  test 'should set lineno to line number in source where list starts' do
    input = <<~'EOS'
    * bullet 1
    ** bullet 1.1
    *** bullet 1.1.1
    * bullet 2
    EOS
    doc = document_from_string input, sourcemap: true
    lists = doc.find_by context: :ulist
    assert_equal 1, lists[0].lineno
    assert_equal 2, lists[1].lineno
    assert_equal 3, lists[2].lineno

    list_items = doc.find_by context: :list_item
    assert_equal 1, list_items[0].lineno
    assert_equal 2, list_items[1].lineno
    assert_equal 3, list_items[2].lineno
    assert_equal 4, list_items[3].lineno
  end
end
