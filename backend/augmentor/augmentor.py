import spacy
import lemminflect  # import is 'unused' but necessary to enable the extension
import copy
import random
import asyncio
from typing import List, Tuple, Optional
import traceback
from dataclasses import dataclass

@dataclass
class ExactRule:
    source: str
    target: str
    aug_pos: str
    aug_tag: str
    aug_feat: Optional[str]
    probability: float

@dataclass
class DependencyRule:
    dep_rel: str
    child_pos_list: List[str]
    head_pos_list: List[str]
    old_tag_list: List[str]
    aug_tag: str
    child: bool
    aug_feat: Optional[str]
    probability: float

# mapping to automatically update POS if the new tag falls under a different POS category
tag_to_pos = {
    'JJ': 'ADJ',
    'JJR': 'ADJ',
    'JJS': 'ADJ',
    'RB': 'ADV',
    'RBR': 'ADV',
    'RBS': 'ADV',
    'WRB': 'ADV',
    'IN': 'ADP',
    'RP': 'ADP',
    'VB': 'VERB',
    'VBD': 'VERB',
    'VBG': 'VERB',
    'VBN': 'VERB',
    'VBP': 'VERB',
    'VBZ': 'VERB',
    'MD': 'VERB',
    'CC': 'CCONJ',
    'DT': 'DET',
    'PDT': 'DET',
    'PRP$': 'DET',
    'WDT': 'DET',
    'WP$': 'DET',
    'UH': 'INTJ',
    'NN': 'NOUN',
    'NNS': 'NOUN',
    'POS': 'PART',
    'TO': 'PART',
    'NNP': 'PROPN',
    'NNPS': 'PROPN',
}

class ConlluAugmentor:
    '''A class to augment a dataset of .conllu files by injecting errors into sentences of interest'''
    
    def __init__(
        self,
        rules: List[Tuple]=None,
        model: str='en_core_web_sm',
        ADJECTIVE_TO_ADVERB: dict=None,
        ADVERB_TO_ADJECTIVE: dict=None,
        s3_bucket: str=None,
    ):
        self.rules = rules
        self.nlp = spacy.load(model)
        self.ADJECTIVE_TO_ADVERB = ADJECTIVE_TO_ADVERB
        self.ADVERB_TO_ADJECTIVE = ADVERB_TO_ADJECTIVE
        self.s3_bucket = s3_bucket

    def get_forms(self, word: str, lemma: str, tag: str) -> Optional[str]:
        """get inflected form of a word given its lemma and target tag"""
        lemma = self.nlp(word)[0]._.lemma()
        word = word.lower()
        
        if tag in ['RB', 'RBR', 'RBS']:
            if word in self.ADJECTIVE_TO_ADVERB:
                form = self.ADJECTIVE_TO_ADVERB[word].lower()
                if form != word:
                    print(f'Found {tag} form for {word}: {form}')
                    return form
            return None
        elif tag in ['JJ', 'JJR', 'JJS']:
            if word in self.ADVERB_TO_ADJECTIVE:
                form = self.ADVERB_TO_ADJECTIVE[word].lower()
                if form != word:
                    print(f'Found {tag} form for {word}: {form}')
                    return form
                return None
        
        form = self.nlp(lemma)[0]._.inflect(tag).lower()
        if form != word:
            print(f'Found {tag} form for {word}: {form}')
            return form
    
        print(f'Could not find {tag} form for: {word}')
        return None
            
    def format_data(self, data: str) -> List[List[str]]:
        """format string of conllu data into a list of sentences"""
        data = data.split('# sent_id =')[1:]
        splitted_data = ['' for _ in range(len(data))]

        for item in data:
            item_split = item.split('\n', 1)
            sent_id = int(item_split[0])
            lines = item_split[1].split('\n')
            split_lines = [line.split('\t') for line in lines if line.strip()]
            splitted_data[sent_id] = split_lines
        
        return splitted_data
    
    def reverse_format_data(self, sentence: List[List[str]], sent_id: int) -> str:
        """reverse the sentence back to CoNLL-U format"""
        lines = ['\t'.join(word) for word in sentence]
        return f'# sent_id = {sent_id}\n' + '\n'.join(lines) + '\n\n'
    
    def _augment_sentence_exact(self, rule: Tuple, sentence_deep_copy: List[str]) -> List[str]:
        source, target, aug_pos, aug_tag, aug_feat, probability = rule
        for index, word in enumerate(sentence_deep_copy):
            # by default, this is child=True
            if word[1] == source and random.uniform(0, 1) < probability:
                print(f'changing {source} to {target}')
                sentence_deep_copy[index][1] = target
                sentence_deep_copy[index][3] = aug_pos
                sentence_deep_copy[index][4] = aug_tag
                if aug_feat:
                    sentence_deep_copy[index][5] = aug_feat
                return sentence_deep_copy
        return []

    # automatically updates POS if the new tag falls under a different POS category
    def _augment_sentence_dependency(self, rule: Tuple, sentence_original: List[str], sentence_deep_copy: List[str]) -> List[str]:
        dep_rel, child_pos_list, head_pos_list, old_tag_list, aug_tag, child, aug_feat, probability = rule
        for index, word in enumerate(sentence_deep_copy):
            # word matches dependency relation, child pos, and head pos
            if word[7] == dep_rel and word[3] in child_pos_list and sentence_original[int(word[6])-1][3] in head_pos_list and random.uniform(0, 1) < probability: 
                # update tag of child if child is True and child tag is in old_tag_list
                if child and sentence_original[index][4] in old_tag_list:
                    new_form = self.get_forms(word[1], word[2], aug_tag)
                    if new_form:
                        sentence_deep_copy[index][4] = aug_tag
                        sentence_deep_copy[index][1] = new_form
                        sentence_deep_copy[index][3] = tag_to_pos[aug_tag]
                        if aug_feat:
                            sentence_deep_copy[index][5] = aug_feat
                    else:
                        return []
                # update tag of head if child is False and head exists and head tag is in old_tag_list
                elif int(word[6]) > 0 and sentence_original[int(word[6])-1][4] in old_tag_list:
                    head_index = int(word[6]) - 1   # words are 1-indexed in conllu
                    new_form = self.get_forms(sentence_original[head_index][1], sentence_original[head_index][2], aug_tag)
                    if new_form:
                        sentence_deep_copy[head_index][4] = aug_tag 
                        sentence_deep_copy[head_index][1] = new_form
                        sentence_deep_copy[head_index][3] = tag_to_pos[aug_tag]
                        if aug_feat:
                            sentence_deep_copy[head_index][5] = aug_feat
                    else:
                        return []
                else:
                    continue    
                
                return sentence_deep_copy 
        return []
    
    def augment_sentence(self, sentence: List[List[str]]) -> List[List[str]]:
        """augment a single sentence based on the provided rules"""
        shuffled_rules = random.sample(self.rules, len(self.rules))
        aug_sentence = copy.deepcopy(sentence)

        for rule in shuffled_rules:
            if isinstance(rule, ExactRule):
                # exact match rule
                aug_sentence = self._augment_sentence_exact(rule, aug_sentence)
            elif isinstance(rule, DependencyRule):
                # dependency based rule
                aug_sentence = self._augment_sentence_dependency(rule, sentence, aug_sentence)
            
            if aug_sentence != []:
                # if aug was successful return it, else try the next (shuffled) rule
                return aug_sentence
            
        return [] # no rule matched

    async def download_from_s3(self, s3_client, s3_key: str) -> str:
        """get a file from S3 and return its content"""
        try:
            response = await s3_client.get_object(Bucket=self.s3_bucket, Key=s3_key)
            async with response['Body'] as stream:
                content = await stream.read()
                return content.decode('utf-8')
        except Exception as e:
            print(f'Error downloading {s3_key}: {e}')
            raise

    async def upload_to_s3(self, s3_client, s3_key: str, content: str) -> None:
        """upload content to S3"""
        try:
            await s3_client.put_object(
                Bucket=self.s3_bucket,
                Key=s3_key,
                Body=content.encode('utf-8')
            )
            print(f'Successfully uploaded {s3_key}')
        except Exception as e:
            print(f'Error uploading {s3_key}: {e}')
            raise

    def generate_augmented_key(self, original_key: str) -> str:
        """generate S3 key for augmented file"""
        parts = original_key.rsplit('/', 1) # split into path and filename
        if len(parts) == 2:
            path, filename = parts
            return f"{path}/aug_{filename}"
        else:
            return f"aug_{original_key}"

    async def augment_s3_file(self, s3_client, s3_key: str) -> Optional[str]:
        """augment a single S3 file and upload the result"""
        if self.rules is None:
            raise ValueError('No rules specified for augmentation')

        try:
            print(f'Processing {s3_key}...')
        
            content = await self.download_from_s3(s3_client, s3_key)

            formatted_data = self.format_data(content)
            augmented_sentences = []
            
            for sent_id, sentence in enumerate(formatted_data):
                aug_sentence = self.augment_sentence(sentence)
                if aug_sentence:
                    augmented_sentences.append(
                        self.reverse_format_data(aug_sentence, sent_id)
                    )
            
            if not augmented_sentences:
                print(f'No augmentations generated for {s3_key}')
                return None
            
            augmented_content = ''.join(augmented_sentences)
            
            # upload to s3
            augmented_key = self.generate_augmented_key(s3_key)
            await self.upload_to_s3(s3_client, augmented_key, augmented_content)
            
            return augmented_key
            
        except Exception as e:
            print(f'Error processing {s3_key}: {e}')
            traceback.print_exc()
            return None

    async def run(self, s3_client, s3_keys: List[str]) -> List[str]:
        """process multiple S3 files concurrently"""
        semaphore = asyncio.Semaphore(40)  # limit to 40 concurrent tasks

        async def sem_augment_s3_file(s3_client, s3_key):
            async with semaphore:
                return await self.augment_s3_file(s3_client, s3_key)

        tasks = [sem_augment_s3_file(s3_client, key) for key in s3_keys]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        successful = []
        failed = []
        no_augmentations = []

        for i, result in enumerate(results):
            original_key = s3_keys[i]
            
            if isinstance(result, Exception):
                # exception occurred during processing
                failed.append({
                    'original_key': original_key,
                    'error': str(result),
                    'error_type': type(result).__name__
                })
            elif result is None:
                # no augmentations were generated
                no_augmentations.append({
                    'original_key': original_key,
                    'error': 'No sentences matched any augmentation rules'
                })
            else:
                # success
                successful.append({
                    'original_key': original_key,
                    'augmented_key': result
                })

        return {
            'successful': successful,
            'failed': failed,
            'no_augmentations': no_augmentations,
            'summary': {
                'total': len(s3_keys),
                'successful': len(successful),
                'failed': len(failed),
                'no_augmentations': len(no_augmentations)
            }
        }