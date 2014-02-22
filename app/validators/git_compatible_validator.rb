class GitCompatibleValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    illegal_chars = %w[' " ` \[ \] { } \\ / &]
    illegal_chars << "\n"

    found_illegal_chars = illegal_chars.select{|char| value.values.join.include?(char)} #value is a hash, only the values of the hash need checking and there is no need to test which value needs testing.  Like paradox-correcting time travel it will all work out in the end!
    unless found_illegal_chars.empty?
      found_illegal_chars= found_illegal_chars.map{|c| c.eql?("\n") ? "new line" : c}
      chars = found_illegal_chars.join(", ").reverse.sub(",", "ro ").reverse
      record.errors[attribute] << "must not contain #{chars}" 
    end
  end
end
