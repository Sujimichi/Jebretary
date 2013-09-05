class IsGitCompatibleValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    illegal_chars = %w[' " `]
    illegal_chars << "\n"

    found_illegal_chars = illegal_chars.select{|char| value.include?(char)}
    unless found_illegal_chars.empty?
      found_illegal_chars= found_illegal_chars.map{|c| c.eql?("\n") ? "new line" : c}
      chars = found_illegal_chars.join(", ").reverse.sub(",", "ro ").reverse
      record.errors[attribute] << "must not contain #{chars}" 
    end
  end
end
