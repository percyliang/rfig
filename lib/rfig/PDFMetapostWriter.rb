############################################################
# Generates a PDF through metapost.

require 'rfig/MetapostWriter'

class PDFMetapostWriter < MetapostWriter
  def init(outPrefix, latexHeader, defaultFont, fontSize, verbose)
    super(outPrefix, latexHeader, defaultFont, fontSize, verbose)
  end
  def finish
    return unless opened?
    mpPath = @mpPath
    super()
    logPath = mpPath.sub(/\.mp$/, '.log')
    # Compile the metapost into PDF
    # Don't need the metapost anymore
    libDir = File.dirname(__FILE__)
    mpto1pdf = "#{libDir}/../../bin/mpto1pdf"
    if not ExternalCommand.exec(:command => mpto1pdf, :abortIfFail => false,
        :args => [@verbose ? nil : '-quiet', mpPath].compact) then
      puts "Error converting MP to PDF; see error in #{logPath} (good luck)."
      puts "Also look in #{IO.readlines(logPath)[0].split[-1]}/mpxerr.log"
      exit 1
    end
    File.unlink(mpPath)
    File.unlink(logPath) if File.exists?(logPath)
    mpPath.sub(/\.mp$/, '.pdf')
  end
end
