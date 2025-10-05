from augmentor import ConlluAugmentor
import json
import aioboto3
import time
import asyncio

async def create_s3_client(assume_role_arn: str):
    """create an s3 client using an assume role to access external bucket"""
    session = aioboto3.Session()

    if not assume_role_arn:
        return {
            'statusCode': 400,
            'body': json.dumps('No assume role ARN provided')
        }

    async with session.client('sts') as sts:
        res = await sts.assume_role(
            RoleArn=assume_role_arn,
            RoleSessionName=f'augmentor-session-{int(time.time())}'
        )
        credentials = res['Credentials']

        s3_client = session.client(
            's3',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken']
        )

        return s3_client
    
async def process_augmentation(event):
    with open ('adj_to_adv.json', 'r') as f:
        ADJECTIVE_TO_ADVERB = json.load(f)
    with open ('adv_to_adj.json', 'r') as f:
        ADVERB_TO_ADJECTIVE = json.load(f)

    # convert rules to list of tuples
    rules = event.get('rules')
    rules = [tuple(rule) for rule in rules] if rules else []

    if len(rules) == 0:
        return {
            'statusCode': 400,
            'body': json.dumps('No rules provided for augmentation')
        }
    
    s3_keys = event.get('s3_keys', [])
    if len(s3_keys) == 0:
        return {
            'statusCode': 400,
            'body': json.dumps('No S3 keys provided for augmentation')
        }
    
    # inputs are validated before this function is called, dont worry
    augmentor = ConlluAugmentor(
        rules=rules,
        s3_bucket=event.get('s3_bucket'),
        ADJECTIVE_TO_ADVERB=ADJECTIVE_TO_ADVERB,
        ADVERB_TO_ADJECTIVE=ADVERB_TO_ADJECTIVE
    )

    async with await create_s3_client(event.get('s3_assume_role_arn')) as s3_client:
        augmented_keys = await augmentor.run(s3_client, s3_keys)

    return {
        'statusCode': 200,
        'body': json.dumps({
            'augmented_keys': augmented_keys
        })
    }

def lambda_handler(event, context):
    try:
        res = asyncio.run(process_augmentation(event))
        return res
    except Exception as e:
        print(f'Error in lambda_handler: {e}')
        return {
            'statusCode': 500,
            'body': json.dumps(f'Internal server error: {e}')
        }

if __name__ == "__main__":
    sample_rules = [
        # begin exact match rules
        # 1. there/their (cant do they're because it contains apostrophe unfortunately and spacy separates into two tokens thus too complicated)
        # 2. I/me, he/him, she/her, we/us, they/them (subjective<->objective pronouns)
        # 3. affect/effect
        # 4. than/then
        # 5. to/too/two
        ("there", "their", "PRON", "PRP$", "Case=Gen|Number=Plur|Person=3|Poss=Yes|PronType=Prs", 0.2),
        ("their", "there", "ADV", "RB", "", 0.2),
        ("I", "me", "PRON", "PRP", "Case=Acc|Number=Sing|Person=1|PronType=Prs", 0.5),
        ("me", "I", "PRON", "PRP", "Case=Nom|Number=Sing|Person=1|PronType=Prs", 0.5),  
        ("he", "him", "PRON", "PRP", "Case=Acc|Gender=Masc|Number=Sing|Person=3|PronType=Prs", 0.5),
        ("him", "he", "PRON", "PRP", "Case=Nom|Gender=Masc|Number=Sing|Person=3|PronType=Prs", 0.5),  
        ("she", "her", "PRON", "PRP", "Case=Acc|Gender=Fem|Number=Sing|Person=3|PronType=Prs", 0.5),
        ("her", "she", "PRON", "PRP", "Case=Nom|Gender=Fem|Number=Sing|Person=3|PronType=Prs", 0.5),
        ("we", "us", "PRON", "PRP", "Case=Acc|Number=Plur|Person=1|PronType=Prs", 0.5),
        ("us", "we", "PRON", "PRP", "Case=Nom|Number=Plur|Person=1|PronType=Prs", 0.5),
        ("they", "them", "PRON", "PRP", "Case=Acc|Number=Plur|Person=3|PronType=Prs", 0.5),
        ("them", "they", "PRON", "PRP", "Case=Nom|Number=Plur|Person=3|PronType=Prs", 0.5),
        ("affect", "effect", "NOUN", "NN", "Number=Sing", 0.4),
        ("effect", "affect", "VERB", "VB", "", 0.4),
        ("than", "then", "ADV", "RB", "", 0.8),
        ("then", "than", "ADP", "IN", "", 0.8),
        ("to", "too", "ADV", "RB", "", 0.8),
        ("too", "to", "PART", "TO", "", 0.8),
        ("to", "two", "NUM", "CD", "NumForm=Word|NumType=Card", 0.8),
        ("two", "to", "PART", "TO", "", 0.8),
        ("two", "too", "ADV", "RB", "", 0.8),
        ("too", "two", "NUM", "CD", "NumForm=Word|NumType=Card", 0.8),
        # begin dependency based rules
        # 1. change gerunds and past tense verbs to base form verbs
        # 2. change plural verbs to singular and vice versa
        # 3. change adjectives to adverbs and vice versa
        # 4. change base form verbs after modals to gerunds
        # 5. change base form verbs after modal to past tense verbs 
        # 6. change gerunds after prepositions to base form verbs
        # 7. change 'is' to 'are'
        ('nsubj', ['NOUN', 'PROPN'], ['VERB'], ['VBD', 'VBG'], 'VB', False, '', 0.25),  
        ('nsubj', ['NOUN', 'PROPN'], ['VERB'], ['VBZ', 'VBD'], 'VBP', True, '', 0.25),
        ('nsubj', ['NOUN', 'PROPN'], ['VERB'], ['VBP', 'VBD'], 'VBZ', True, '', 0.25),
        ('advmod', ['ADV'], ['VERB'], ['RB'], 'JJ', True, '', 0.45),
        ('amod', ['ADJ'], ['NOUN'], ['JJ'], 'RB', True, '', 0.30),  
        ('aux', ['AUX'], ['VERB'], ['VB'], 'VBG', False, '', 0.30),
        ('aux', ['AUX'], ['VERB'], ['VB'], 'VBD', False, '', 0.30),
        ('case', ['ADP'], ['VERB'], ['VBG'], 'VB', False, '', 0.60),
        ('cop', ['AUX'], ['VERB', 'ADJ', 'ADV'], ['VBZ'], 'VBP', True, 'Mood=Ind|Number=Sing|Person=1|Tense=Pres|VerbForm=Fin', 0.30),
        ('cop', ['AUX'], ['VERB', 'ADJ', 'ADV'], ['VB', 'VBP'], 'VBZ', True, 'Mood=Ind|Number=Sing|Person=3|Tense=Pres|VerbForm=Fin', 0.30),
        ('cop', ['AUX'], ['VERB', 'ADJ', 'ADV'], ['VB', 'VBZ', 'VBP'], 'VBD', True, 'Mood=Ind|Number=Sing|Person=3|Tense=Past|VerbForm=Fin', 0.30),
        ('cop', ['AUX'], ['VERB', 'ADJ', 'ADV'], ['VB', 'VBD'], 'VBG', True, 'Tense=Pres|VerbForm=Part', 0.30),
    ]

    event = {
        "rules": sample_rules,
        "s3_bucket": "sixsevenlabs",
        "s3_assume_role_arn": "arn:aws:iam::123456789012:role/YourRoleName",
        "s3_keys": [
            "sample1.conllu",
            "sample2.conllu"
        ]
    }

    print(lambda_handler(event, None))