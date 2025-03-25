# frozen_string_literal: true

require 'caxlsx'

module Labimotion
  ## XlsxExporter
  # A common utility class for exporting data to Excel (.xlsx) format using the caxlsx gem
  #
  # Usage Example:
  #   exporter = Labimotion::XlsxExporter.new('MyReport')
  #   exporter.add_worksheet('Sheet1') do |sheet|
  #     sheet.add_header(['Name', 'Age', 'Email'])
  #     sheet.add_row(['Jane Smith', 25, 'jane@example.com'])
  #   end
  #   exporter.save_to_file('output.xlsx')
  #   # or get the stream: exporter.to_stream
  class XlsxExporter
    attr_reader :package, :workbook

    # Initialize a new XlsxExporter
    # @param filename [String] optional filename (without extension)
    def initialize(filename = nil)
      @filename = filename
      @package = Axlsx::Package.new
      @workbook = @package.workbook
      @workbook.styles.fonts.first.name = 'Calibri'
      @current_sheet = nil
    end

    # Add a new worksheet to the workbook
    # @param sheet_name [String] name of the worksheet
    # @param options [Hash] additional options for the worksheet
    # @yield [sheet] gives the SheetBuilder to the block
    # @return [SheetBuilder] the created sheet builder
    def add_worksheet(sheet_name, _options = {}, &block)
      sheet = SheetBuilder.new(@workbook.add_worksheet(name: sheet_name), @workbook)
      sheet.instance_eval(&block) if block_given?
      sheet
    end

    # Get the Excel file as a stream
    # @return [String] the Excel file stream
    def to_stream
      @package.to_stream
    end

    # Read the Excel file content
    # @return [String] the Excel file binary content
    def read
      @package.to_stream.read
    end

    # Save the Excel file to disk
    # @param filepath [String] path where to save the file
    # @return [Boolean] true if saved successfully
    def save_to_file(filepath)
      @package.serialize(filepath)
      true
    rescue StandardError => e
      Labimotion.log_exception(e)
      false
    end

    # Get suggested filename with .xlsx extension
    # @return [String] filename with extension
    def filename
      name = @filename || "export_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      "#{name}.xlsx"
    end

    ## SheetBuilder
    # Helper class to build worksheet content with convenient methods
    class SheetBuilder
      attr_reader :sheet, :workbook, :styles

      def initialize(sheet, workbook)
        @sheet = sheet
        @workbook = workbook
        @styles = StyleManager.new(workbook)
        @current_row = 0
      end

      # Add a header row with bold styling
      # @param data [Array] array of header values
      # @param options [Hash] style options (color, bg_color, bold, etc.)
      # @return [Integer] row index
      def add_header(data, options = {})
        style_options = {
          bold: true,
          fg_color: '000000', # Black text
          bg_color: 'DDDDDD',
          border: { style: :thin, color: '000000' }
        }.merge(options)

        style = @styles.create_style(style_options)
        add_row(data, style: style)
      end

      # Add a data row
      # @param data [Array] array of cell values
      # @param options [Hash] options including :style, :height, :types
      # @return [Integer] row index
      def add_row(data, options = {})
        row_options = {}
        row_options[:style] = options[:style] if options[:style]
        row_options[:height] = options[:height] if options[:height]
        row_options[:types] = options[:types] if options[:types]

        @sheet.add_row(data, row_options)
        @current_row += 1
        @current_row - 1
      end

      # Add multiple rows at once
      # @param rows [Array<Array>] array of row data
      # @param options [Hash] options for all rows
      # @return [Integer] number of rows added
      def add_rows(rows, options = {})
        rows.each { |row| add_row(row, options) }
        rows.length
      end

      # Add an empty row (for spacing)
      # @return [Integer] row index
      def add_blank_row
        add_row([])
      end

      # Set column widths
      # @param widths [Array<Numeric>] array of column widths
      def set_column_widths(*widths)
        @sheet.column_widths(*widths)
      end

      # Auto-fit column widths based on content
      # @param columns [Array<Integer>] column indices to auto-fit (nil for all)
      def auto_fit_columns(columns = nil)
        cols = columns || (0...(@sheet.rows.first&.cells&.length || 0)).to_a
        cols.each do |col_index|
          max_width = @sheet.rows.map { |row| row.cells[col_index]&.value.to_s.length || 0 }.max
          @sheet.column_info[col_index].width = [max_width + 2, 100].min if max_width
        end
      end

      # Merge cells in a range
      # @param start_cell [String] starting cell (e.g., 'A1')
      # @param end_cell [String] ending cell (e.g., 'C1')
      def merge_cells(start_cell, end_cell)
        @sheet.merge_cells("#{start_cell}:#{end_cell}")
      end

      # Add a titled section (title + data rows)
      # @param title [String] section title
      # @param data [Array<Array>] data rows
      # @param options [Hash] options for the section
      def add_section(title, data, options = {})
        add_blank_row if @current_row.positive?

        # Add title
        title_style = @styles.create_style(
          bold: true,
          font_size: 14,
          bg_color: options[:title_bg_color] || 'CCCCCC'
        )
        add_row([title], style: title_style)

        # Add data
        add_rows(data, options)

        add_blank_row
      end

      # Freeze panes (typically for freezing header rows)
      # @param row [Integer] row number to freeze at
      # @param column [Integer] column number to freeze at
      def freeze_panes(row = 1, column = 0)
        @sheet.sheet_view.pane do |pane|
          pane.top_left_cell = Axlsx.cell_r(column, row)
          pane.state = :frozen
          pane.y_split = row
          pane.x_split = column
          pane.active_pane = :bottom_right
        end
      end

      # Apply auto-filter to a range
      # @param range [String] range to apply filter (e.g., 'A1:D1')
      def add_auto_filter(range = nil)
        if range
          @sheet.auto_filter = range
        else
          # Auto-detect range from first row
          last_col = (@sheet.rows.first&.cells&.length || 1) - 1
          @sheet.auto_filter = "A1:#{Axlsx.col_ref(last_col)}1"
        end
      end

      # Add a hyperlink to a specific cell
      # @param row_index [Integer] 0-based row index
      # @param col_index [Integer] 0-based column index
      # @param url [String] the URL for the hyperlink
      # @param display_text [String] optional display text (defaults to cell value)
      def add_hyperlink(row_index, col_index, url, display_text = nil)
        cell = @sheet.rows[row_index].cells[col_index]
        cell.value = display_text if display_text
        @sheet.add_hyperlink location: url, ref: cell
      end
    end

    ## StyleManager
    # Helper class to manage and create cell styles
    class StyleManager
      def initialize(workbook)
        @workbook = workbook
        @style_cache = {}
      end

      # Create or retrieve a cached style
      # @param options [Hash] style options
      # @option options [Boolean] :bold
      # @option options [Boolean] :italic
      # @option options [String] :font_name
      # @option options [Integer] :font_size
      # @option options [String] :fg_color foreground/text color
      # @option options [String] :bg_color background color
      # @option options [Symbol] :alignment (:left, :center, :right)
      # @option options [Hash] :border border options
      # @option options [String] :format_code number format
      # @return [Axlsx::Style] the created or cached style
      def create_style(options = {})
        cache_key = options.hash
        return @style_cache[cache_key] if @style_cache[cache_key]

        style_options = {}

        # Font options
        font_options = {}
        font_options[:b] = options[:bold] if options.key?(:bold)
        font_options[:i] = options[:italic] if options.key?(:italic)
        font_options[:name] = options[:font_name] if options[:font_name]
        font_options[:sz] = options[:font_size] if options[:font_size]
        # font_options[:color] = { rgb: options[:fg_color] } if options[:fg_color]
        style_options[:font] = font_options if font_options.any?

        # Fill/background color
        if options[:bg_color]
          style_options[:bg_color] = options[:bg_color]
          style_options[:fg_color] = options[:fg_color]
        end

        # Alignment
        style_options[:alignment] = { horizontal: options[:alignment] } if options[:alignment]

        # Border
        style_options[:border] = options[:border] if options[:border]

        # Number format
        style_options[:format_code] = options[:format_code] if options[:format_code]

        @style_cache[cache_key] = @workbook.styles.add_style(style_options)
      end

      # Common predefined styles
      def header_style
        create_style(bold: true, bg_color: 'DDDDDD', alignment: :center)
      end

      def currency_style
        create_style(format_code: '$#,##0.00')
      end

      def percentage_style
        create_style(format_code: '0.00%')
      end

      def date_style
        create_style(format_code: 'yyyy-mm-dd')
      end

      def datetime_style
        create_style(format_code: 'yyyy-mm-dd hh:mm:ss')
      end
    end
  end
end
