import java.io.*;
import java.util.ArrayList;
import java.util.Random;

public class DocumentGenerator {
    private String[] words;
    private float OVERHEAD_COMPENSATION = 0.955f;

    // JVM arguments:       -Xmx4096m
    // Program arguments:   1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 64 92 128 160 256
    public static void main(String args[]) {
        DocumentGenerator documentGenerator = new DocumentGenerator();

        for (String size : args) {
            documentGenerator.generate(Integer.parseInt(size));
        }
    }

    public DocumentGenerator() {
        ArrayList<String> wordsBuffer = new ArrayList<String>();
        BufferedReader bufferedReader = null;
        String line = null;

        try {
            bufferedReader = new BufferedReader(new FileReader("Dictionary.txt"));
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        try {
            while ((line = bufferedReader.readLine()) != null) {
                wordsBuffer.add(line);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }

        words = new String[wordsBuffer.size()];
        wordsBuffer.toArray(words);
    }

    public void generate(int sizeInMB) {
        int sizeInBytes = 0;
        StringBuffer stringBuffer = new StringBuffer();

        while (sizeInBytes < sizeInMB * 1024 * 1024 * OVERHEAD_COMPENSATION) {
            String w = words[new Random().nextInt(words.length)];
            stringBuffer.append(w);
            stringBuffer.append(" ");

            if (0 == new Random().nextInt(10)) {
                stringBuffer.append('\n');
                sizeInBytes++;
            }

            sizeInBytes = sizeInBytes + 1 + w.length();
        }

        writeDocument(stringBuffer.toString(), sizeInMB);
    }

    private void writeDocument(String document, int sizeInMB) {
        BufferedWriter bufferedWriter = null;
        try {
            bufferedWriter = new BufferedWriter(new FileWriter(sizeInMB + "MB.txt"));
            bufferedWriter.write(document);
            System.out.println(sizeInMB + "MB.txt written.");
        } catch (IOException e) {
        } finally {
            try {
                if (bufferedWriter != null)
                    bufferedWriter.close();
            } catch (IOException e) {
            }
        }
    }
}
